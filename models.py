from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import Column, Integer, String, Text, Numeric, DateTime, BigInteger, Boolean, ForeignKey, Index
from sqlalchemy.orm import declarative_base, relationship
from sqlalchemy.sql import func

Base = declarative_base()
db = SQLAlchemy(model_class=Base)


class User(Base):
    __tablename__ = 'users'
    id = Column(Integer, primary_key=True)
    username = Column(String(80), unique=True, nullable=False)
    password_hash = Column(String(256), nullable=False)
    created_at = Column(DateTime, server_default=func.now())


class PhotoTrap(Base):
    __tablename__ = 'PhotoTrap'
    Id = Column(Integer, primary_key=True, autoincrement=True)
    Name = Column(String(255), nullable=False)
    MacAddress = Column(String(50), unique=True)
    WifiSSID = Column(String(100))
    Description = Column(Text)
    Latitude = Column(Numeric(10, 8))
    Longitude = Column(Numeric(11, 8))
    IsActive = Column(Boolean, default=True, nullable=False)
    CreatedAt = Column(DateTime, server_default=func.now())
    UpdatedAt = Column(DateTime, server_default=func.now())

    download_logs = relationship('DownloadLog', backref='trap', lazy=True, cascade='all, delete-orphan')
    snapshot_logs = relationship('SnapshotLog', backref='trap', lazy=True, cascade='all, delete-orphan')


class CalibrationLog(Base):
    __tablename__ = 'CalibrationLog'
    Id = Column(Integer, primary_key=True, autoincrement=True)
    StartTime = Column(DateTime, nullable=False)
    EndTime = Column(DateTime)
    CamerasFound = Column(Integer, default=0)
    SsidsBound = Column(Integer, default=0)
    LogMessage = Column(Text)
    ErrorMessage = Column(Text)
    CreatedAt = Column(DateTime, server_default=func.now())


Index('idx_callog_starttime', CalibrationLog.StartTime)
Index('idx_callog_createdat', CalibrationLog.CreatedAt)


class SnapshotLog(Base):
    __tablename__ = 'SnapshotLog'
    Id = Column(Integer, primary_key=True, autoincrement=True)
    PhotoTrapId = Column(Integer, ForeignKey('PhotoTrap.Id', ondelete='CASCADE'), nullable=False)
    CycleNumber = Column(Integer)
    StartTime = Column(DateTime, nullable=False)
    EndTime = Column(DateTime)
    FileName = Column(String(255))
    Status = Column(String(20), default='PENDING')
    LogMessage = Column(Text)
    ErrorMessage = Column(Text)
    CreatedAt = Column(DateTime, server_default=func.now())
    ActivityType = Column(String(20), nullable=False, default='photo', server_default='photo')


Index('idx_snaplog_phototrapid', SnapshotLog.PhotoTrapId)
Index('idx_snaplog_starttime', SnapshotLog.StartTime)
Index('idx_snaplog_status', SnapshotLog.Status)
Index('idx_snaplog_createdat', SnapshotLog.CreatedAt)


class DownloadLog(Base):
    __tablename__ = 'DownloadLog'
    Id = Column(Integer, primary_key=True, autoincrement=True)
    PhotoTrapId = Column(Integer, ForeignKey('PhotoTrap.Id', ondelete='CASCADE'), nullable=False)
    FileName = Column(String(255))
    FilePath = Column(String(500))
    FileSize = Column(BigInteger)
    TimeCode = Column(BigInteger)
    FileTime = Column(DateTime)
    IsSuccess = Column(Boolean, default=False)
    IsDeleted = Column(Boolean, default=False)
    IsSent = Column(Boolean, default=False)
    ErrorMessage = Column(Text)
    LocalPath = Column(String(500))
    DownloadedAt = Column(DateTime, server_default=func.now())


Index('idx_dllog_phototrapid', DownloadLog.PhotoTrapId)
Index('idx_dllog_downloadedat', DownloadLog.DownloadedAt)
Index('idx_dllog_issuccess', DownloadLog.IsSuccess)
Index('idx_dllog_filename', DownloadLog.FileName)
Index('idx_dllog_filetime', DownloadLog.FileTime)


class PhotoTrapConfig(Base):
    __tablename__ = 'PhotoTrapConfig'
    Id = Column(Integer, primary_key=True, autoincrement=True)
    Key = Column(String(100), unique=True, nullable=False)
    Value = Column(Text, nullable=False)
    Description = Column(Text)
    CreatedAt = Column(DateTime, server_default=func.now())
    UpdatedAt = Column(DateTime, server_default=func.now())


Index('idx_config_key', PhotoTrapConfig.Key)
