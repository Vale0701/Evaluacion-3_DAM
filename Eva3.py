from fastapi import FastAPI, HTTPException, Depends, status, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from sqlalchemy import create_engine, Column, Integer, BigInteger, String, Enum, Numeric, TIMESTAMP, ForeignKey, text
from sqlalchemy.orm import sessionmaker, declarative_base, Session, relationship
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta
import os
import shutil
import uuid

# ─────────────────────────────────────────────
# CONFIGURACIÓN
# ─────────────────────────────────────────────
DATABASE_URL = os.getenv("DATABASE_URL", "mysql+mysqlconnector://root:123456@127.0.0.1:3307/paquexpres")
SECRET_KEY   = os.getenv("SECRET_KEY", "cambia_esto_en_produccion_usa_una_clave_segura")
ALGORITHM    = "HS256"
TOKEN_EXPIRE_MINUTES = 60

engine       = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
Base         = declarative_base()

pwd_ctx    = CryptContext(schemes=["bcrypt"], deprecated="auto")
bearer_sec = HTTPBearer()

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)


# ─────────────────────────────────────────────
# MODELOS SQLAlchemy
# ─────────────────────────────────────────────
class Agente(Base):
    __tablename__ = "agente"

    id_agen  = Column(Integer, primary_key=True, index=True)
    nombre   = Column(String(50), nullable=False)
    email    = Column(String(50), unique=True, nullable=False)
    passw    = Column(String(255), nullable=False)
    telefono = Column(BigInteger, nullable=True)  # ← BigInteger para números largos

    paquetes = relationship("Paquete", back_populates="agente")


class Cliente(Base):
    __tablename__ = "cliente"

    id_cli   = Column(Integer, primary_key=True, index=True)
    nombre   = Column(String(50), nullable=True)
    ap       = Column(String(50), nullable=True)
    telefono = Column(BigInteger, nullable=True)  # ← BigInteger para números largos

    paquetes = relationship("Paquete", back_populates="cliente")


class Paquete(Base):
    __tablename__ = "paquete"

    id_paq     = Column(Integer, primary_key=True, index=True)
    direc_dest = Column(String(50), nullable=True)
    status     = Column(
        Enum("Pendiente", "En curso", "Detenido", "Recogido", "Entregado"),
        default="Pendiente"
    )
    foto      = Column(String(255), nullable=True)
    latitud   = Column(Numeric(10, 8), nullable=True)
    longitud  = Column(Numeric(11, 8), nullable=True)
    fecha_en  = Column(TIMESTAMP, default=datetime.utcnow)
    id_cli    = Column(Integer, ForeignKey("cliente.id_cli"), nullable=True)
    id_agen   = Column(Integer, ForeignKey("agente.id_agen"), nullable=True)

    cliente = relationship("Cliente", back_populates="paquetes")
    agente  = relationship("Agente",  back_populates="paquetes")


# ─────────────────────────────────────────────
# SCHEMAS Pydantic
# ─────────────────────────────────────────────
class LoginSchema(BaseModel):
    email:    str
    password: str

class TokenSchema(BaseModel):
    access_token: str
    token_type:   str = "bearer"

class AgenteCreate(BaseModel):
    nombre:   str
    email:    EmailStr
    password: str
    telefono: Optional[int] = None

class AgenteOut(BaseModel):
    id_agen:  int
    nombre:   str
    email:    str
    telefono: Optional[int]
    class Config:
        from_attributes = True

class ClienteCreate(BaseModel):
    nombre:   Optional[str] = None
    ap:       Optional[str] = None
    telefono: Optional[int] = None

class ClienteOut(ClienteCreate):
    id_cli: int
    class Config:
        from_attributes = True

class PaqueteOut(BaseModel):
    id_paq:     int
    direc_dest: Optional[str]
    status:     Optional[str]
    foto:       Optional[str]
    latitud:    Optional[float]
    longitud:   Optional[float]
    fecha_en:   Optional[datetime]
    id_cli:     Optional[int]
    id_agen:    Optional[int]
    class Config:
        from_attributes = True

class PaqueteStatusUpdate(BaseModel):
    status: str


# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────
def hash_password(plain: str) -> str:
    return pwd_ctx.hash(plain)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_ctx.verify(plain, hashed)

def create_token(data: dict) -> str:
    payload = data.copy()
    payload["exp"] = datetime.utcnow() + timedelta(minutes=TOKEN_EXPIRE_MINUTES)
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_current_agent(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_sec),
    db: Session = Depends(get_db)
) -> Agente:
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        agent_id: int = int(payload.get("sub"))
    except (JWTError, TypeError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    agente = db.query(Agente).filter(Agente.id_agen == agent_id).first()
    if not agente:
        raise HTTPException(status_code=404, detail="Agente no encontrado")
    return agente


# ─────────────────────────────────────────────
# APP
# ─────────────────────────────────────────────
app = FastAPI(
    title="Paquexpress API",
    version="1.0.0",
    description="Gestión de paquetes con GPS y foto para agentes de entrega",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:39747",
        "http://127.0.0.1:8000",
        "http://localhost:*",
        "*",  # ← permite todo durante desarrollo
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─────────────────────────────────────────────
# AUTH
# ─────────────────────────────────────────────
@app.post("/auth/registro", response_model=AgenteOut, status_code=201, tags=["Auth"])
def registrar_agente(datos: AgenteCreate, db: Session = Depends(get_db)):
    if db.query(Agente).filter(Agente.email == datos.email).first():
        raise HTTPException(status_code=409, detail="El email ya está registrado")
    nuevo = Agente(
        nombre=datos.nombre,
        email=datos.email,
        passw=hash_password(datos.password),
        telefono=datos.telefono,
    )
    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)
    return nuevo


@app.post("/auth/login", response_model=TokenSchema, tags=["Auth"])
def login(datos: LoginSchema, db: Session = Depends(get_db)):
    agente = db.query(Agente).filter(Agente.email == datos.email).first()
    if not agente or not verify_password(datos.password, agente.passw):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email o contraseña incorrectos",
        )
    token = create_token({"sub": str(agente.id_agen), "nombre": agente.nombre})
    return {"access_token": token}


@app.get("/auth/me", response_model=AgenteOut, tags=["Auth"])
def perfil(agente: Agente = Depends(get_current_agent)):
    return agente


# ─────────────────────────────────────────────
# CLIENTES
# ─────────────────────────────────────────────
@app.post("/clientes", response_model=ClienteOut, status_code=201, tags=["Clientes"])
def crear_cliente(
    datos: ClienteCreate,
    db: Session = Depends(get_db),
    _: Agente = Depends(get_current_agent),
):
    cliente = Cliente(**datos.model_dump())
    db.add(cliente)
    db.commit()
    db.refresh(cliente)
    return cliente


@app.get("/clientes", response_model=List[ClienteOut], tags=["Clientes"])
def listar_clientes(
    db: Session = Depends(get_db),
    _: Agente = Depends(get_current_agent),
):
    return db.query(Cliente).all()


# ─────────────────────────────────────────────
# PAQUETES
# ─────────────────────────────────────────────
@app.post("/paquetes", response_model=PaqueteOut, status_code=201, tags=["Paquetes"])
def crear_paquete(
    direc_dest: str           = Form(...),
    latitud:    float         = Form(...),
    longitud:   float         = Form(...),
    id_cli:     Optional[int] = Form(None),
    foto:       Optional[UploadFile] = File(None),
    db:         Session       = Depends(get_db),
    agente:     Agente        = Depends(get_current_agent),
):
    foto_path = None
    if foto:
        ext      = foto.filename.rsplit(".", 1)[-1] if "." in foto.filename else "jpg"
        filename = f"{uuid.uuid4().hex}.{ext}"
        dest     = os.path.join(UPLOAD_DIR, filename)
        with open(dest, "wb") as f:
            shutil.copyfileobj(foto.file, f)
        foto_path = f"/uploads/{filename}"

    nuevo = Paquete(
        direc_dest=direc_dest,
        latitud=latitud,
        longitud=longitud,
        id_cli=id_cli,
        id_agen=agente.id_agen,
        foto=foto_path,
        status="Pendiente",
        fecha_en=datetime.utcnow(),
    )
    db.add(nuevo)
    db.commit()
    db.refresh(nuevo)
    return nuevo


@app.get("/paquetes", response_model=List[PaqueteOut], tags=["Paquetes"])
def listar_paquetes(
    db:     Session = Depends(get_db),
    agente: Agente  = Depends(get_current_agent),
):
    return db.query(Paquete).filter(Paquete.id_agen == agente.id_agen).all()


@app.get("/paquetes/{id_paq}", response_model=PaqueteOut, tags=["Paquetes"])
def detalle_paquete(
    id_paq: int,
    db:     Session = Depends(get_db),
    agente: Agente  = Depends(get_current_agent),
):
    paquete = db.query(Paquete).filter(
        Paquete.id_paq == id_paq,
        Paquete.id_agen == agente.id_agen,
    ).first()
    if not paquete:
        raise HTTPException(status_code=404, detail="Paquete no encontrado")
    return paquete


@app.get("/paquetes/{id_paq}/ubicacion", tags=["Paquetes"])
def ubicacion_paquete(
    id_paq: int,
    db:     Session = Depends(get_db),
    _:      Agente  = Depends(get_current_agent),
):
    paquete = db.query(Paquete).filter(Paquete.id_paq == id_paq).first()
    if not paquete:
        raise HTTPException(status_code=404, detail="Paquete no encontrado")
    if paquete.latitud is None or paquete.longitud is None:
        raise HTTPException(status_code=422, detail="El paquete no tiene coordenadas GPS")
    return {
        "id_paq":     paquete.id_paq,
        "latitud":    float(paquete.latitud),
        "longitud":   float(paquete.longitud),
        "direc_dest": paquete.direc_dest,
        "maps_url":   f"https://www.google.com/maps?q={paquete.latitud},{paquete.longitud}",
    }


@app.patch("/paquetes/{id_paq}/status", response_model=PaqueteOut, tags=["Paquetes"])
def actualizar_status(
    id_paq:  int,
    payload: PaqueteStatusUpdate,
    db:      Session = Depends(get_db),
    agente:  Agente  = Depends(get_current_agent),
):
    valores_validos = {"Pendiente", "En curso", "Detenido", "Recogido", "Entregado"}
    if payload.status not in valores_validos:
        raise HTTPException(
            status_code=422,
            detail=f"Status inválido. Valores permitidos: {valores_validos}",
        )
    paquete = db.query(Paquete).filter(
        Paquete.id_paq == id_paq,
        Paquete.id_agen == agente.id_agen,
    ).first()
    if not paquete:
        raise HTTPException(status_code=404, detail="Paquete no encontrado")
    paquete.status = payload.status
    db.commit()
    db.refresh(paquete)
    return paquete


# ─────────────────────────────────────────────
# HEALTH CHECK
# ─────────────────────────────────────────────
@app.get("/", tags=["Health"])
def root():
    return {"status": "ok", "app": "Paquexpress API v1.0"}