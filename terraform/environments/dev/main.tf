# environments/dev/main.tf

# 1. IAM 모듈 (권한 관리)
module "iam" {
  source = "../../modules/security/iam"

  compartment_id = var.compartment_id
  tenancy_ocid   = var.tenancy_ocid
  environment    = var.environment
  project_name   = var.project_name
  region         = var.region
}

# 2. Vault 모듈 (시크릿 관리)
module "vault" {
  source = "../../modules/security/vault"

  compartment_id = var.compartment_id
  project_name   = var.project_name
  environment    = var.environment

  # 시크릿 값 설정
  db_root_password = var.db_root_password
  db_app_password  = var.db_app_password
  redis_password   = var.redis_password
  jwt_secret       = var.jwt_secret
  turn_user        = var.turn_user
  turn_password    = var.turn_password
  turn_realm       = var.turn_realm

  depends_on = [module.iam]
}

# 3. Network 모듈 (네트워크 인프라)
module "network" {
  source = "../../modules/network"

  compartment_id = var.compartment_id
  environment    = "dev"
  project_name   = var.project_name
  region         = var.region

  # VCN 및 서브넷 CIDR 설정
  vcn_cidr                     = "10.0.0.0/16"
  public_subnet_cidr           = "10.0.1.0/24" # 로드밸런서, Coturn용
  private_app_subnet_cidr      = "10.0.2.0/24" # API 서버용
  private_database_subnet_cidr = "10.0.3.0/24" # PostgreSQL, Redis용

  # WebRTC 관련 포트 설정
  allowed_webrtc_ports = {
    min = 49152
    max = 65535
  }

  additional_tags = var.additional_tags
}

# 4. Storage 모듈
module "storage" {
  source = "../../modules/storage"

  region             = var.region
  compartment_id     = var.compartment_id
  bucket_name        = "${var.project_name}-${var.environment}"
  bucket_access_type = "NoPublicAccess"
  versioning         = "Enabled"
  storage_tier       = "Standard"
  environment        = var.environment
  project_name       = var.project_name
  domain_name        = var.domain_name

  # 객체 이벤트 활성화
  object_events_enabled = true

  # CORS 규칙 설정
  cors_rules = [
    {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS"]
      allowed_origins    = ["https://*.${var.domain_name}"]
      expose_headers     = ["ETag", "Content-Type"]
      max_age_in_seconds = 3600
    }
  ]

  # 라이프사이클 정책 설정 - 요금제별로 다르게 설정
  lifecycle_rules = [
    # 무료 요금제 VOD (7일 후 삭제)
    {
      name        = "delete-free-tier-vod"
      target      = "objects"
      action      = "DELETE"
      time_amount = 7
      time_unit   = "DAYS"
      prefix      = "vod/free/"
    },
    # 기본 요금제 VOD (14일 후 삭제)
    {
      name        = "delete-standard-tier-vod"
      target      = "objects"
      action      = "DELETE"
      time_amount = 14
      time_unit   = "DAYS"
      prefix      = "vod/standard/"
    },
    # 프리미엄 요금제 VOD (30일 후 삭제)
    {
      name        = "delete-premium-tier-vod"
      target      = "objects"
      action      = "DELETE"
      time_amount = 30
      time_unit   = "DAYS"
      prefix      = "vod/premium/"
    },
    # 다운로드 폴더 임시 파일 (1일 후 삭제)
    {
      name        = "delete-temp-downloads"
      target      = "objects"
      action      = "DELETE"
      time_amount = 1
      time_unit   = "DAYS"
      prefix      = "downloads/temp/"
    }
  ]

  # 폴더 구조 초기화
  create_folder_structure = true
  initial_folders = [
    "vod/free",
    "vod/standard",
    "vod/premium",
    "frontend/static/js",
    "frontend/static/css",
    "frontend/static/images",
    "assets/common",
    "downloads/temp"
  ]

  additional_tags = var.additional_tags

  # IAM 모듈에 의존성 추가 - 관리자 그룹 생성 후 스토리지 정책 적용하기 위함
  depends_on = [module.iam]
}
