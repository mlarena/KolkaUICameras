-- Таблица фото ловушек
CREATE TABLE "PhotoTrap" (
    "Id" SERIAL PRIMARY KEY,
    "Name" VARCHAR(255) NOT NULL,
    "MacAddress" VARCHAR(50) UNIQUE,
    "WifiSSID" VARCHAR(100),
    "Description" TEXT,
    "Latitude" DECIMAL(10, 8),
    "Longitude" DECIMAL(11, 8),
    "IsActive" BOOLEAN DEFAULT TRUE NOT NULL,
    "CreatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "UpdatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица логов калибровки
CREATE TABLE "CalibrationLog" (
    "Id" SERIAL PRIMARY KEY,
    "StartTime" TIMESTAMP NOT NULL,
    "EndTime" TIMESTAMP,
    "CamerasFound" INTEGER DEFAULT 0,
    "SsidsBound" INTEGER DEFAULT 0,
    "LogMessage" TEXT,
    "ErrorMessage" TEXT,
    "CreatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "idx_callog_starttime" ON "CalibrationLog"("StartTime");
CREATE INDEX "idx_callog_createdat" ON "CalibrationLog"("CreatedAt");

-- Таблица логов создания снимков
CREATE TABLE "SnapshotLog" (
    "Id" SERIAL PRIMARY KEY,
    "PhotoTrapId" INTEGER NOT NULL REFERENCES "PhotoTrap"("Id") ON DELETE CASCADE,
    "CycleNumber" INTEGER,
    "StartTime" TIMESTAMP NOT NULL,
    "EndTime" TIMESTAMP,
    "FileName" VARCHAR(255),
    "Status" VARCHAR(20) DEFAULT 'PENDING',
    "ActivityType" VARCHAR(20) NOT NULL DEFAULT 'photo',
    "LogMessage" TEXT,
    "ErrorMessage" TEXT,
    "CreatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "idx_snaplog_phototrapid" ON "SnapshotLog"("PhotoTrapId");
CREATE INDEX "idx_snaplog_starttime" ON "SnapshotLog"("StartTime");
CREATE INDEX "idx_snaplog_status" ON "SnapshotLog"("Status");
CREATE INDEX "idx_snaplog_createdat" ON "SnapshotLog"("CreatedAt");
CREATE INDEX "idx_snaplog_activitytype" ON "SnapshotLog"("ActivityType");

-- Таблица логов загрузки файлов
CREATE TABLE "DownloadLog" (
    "Id" SERIAL PRIMARY KEY,
    "PhotoTrapId" INTEGER NOT NULL REFERENCES "PhotoTrap"("Id") ON DELETE CASCADE,
    "FileName" VARCHAR(255),
    "FilePath" VARCHAR(500),
    "FileSize" BIGINT,
    "TimeCode" BIGINT,
    "FileTime" TIMESTAMP,
    "IsSuccess" BOOLEAN DEFAULT FALSE,
    "IsDeleted" BOOLEAN DEFAULT FALSE,
    "IsSent" BOOLEAN DEFAULT FALSE,
    "ErrorMessage" TEXT,
    "LocalPath" VARCHAR(500),
    "DownloadedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "idx_dllog_phototrapid" ON "DownloadLog"("PhotoTrapId");
CREATE INDEX "idx_dllog_downloadedat" ON "DownloadLog"("DownloadedAt");
CREATE INDEX "idx_dllog_issuccess" ON "DownloadLog"("IsSuccess");
CREATE INDEX "idx_dllog_filename" ON "DownloadLog"("FileName");
CREATE INDEX "idx_dllog_filetime" ON "DownloadLog"("FileTime");

-- Таблица конфигурации приложения
CREATE TABLE "PhotoTrapConfig" (
    "Id" SERIAL PRIMARY KEY,
    "Key" VARCHAR(100) NOT NULL UNIQUE,
    "Value" TEXT NOT NULL,
    "Description" TEXT,
    "CreatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "UpdatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "idx_config_key" ON "PhotoTrapConfig"("Key");

CREATE TABLE public.users (
	id serial4 NOT NULL,
	username varchar(80) NOT NULL,
	password_hash varchar(256) NOT NULL,
	created_at timestamp DEFAULT now() NULL,
	CONSTRAINT users_pkey PRIMARY KEY (id),
	CONSTRAINT users_username_key UNIQUE (username)
);
