from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Application
    app_name: str = "SafeGuard API"
    app_version: str = "1.0.0"
    debug: bool = True

    # Database
    database_url: str = "sqlite:///./safeguard.db"

    # Group Safety
    default_group_range_km: float = 1.5

    # Location monitoring
    location_update_interval_seconds: int = 15

    # Safety thresholds
    medium_risk_threshold: int = 35
    high_risk_threshold: int = 60
    critical_risk_threshold: int = 80

    # Privacy
    default_location_sharing: bool = False
    emergency_location_sharing: bool = True

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )


settings = Settings()