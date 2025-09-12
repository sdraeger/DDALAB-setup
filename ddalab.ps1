# DDALAB Management Script for Windows PowerShell

param(
    [Parameter(Position=0)]
    [ValidateSet('start', 'stop', 'restart', 'update', 'logs', 'status', 'backup', 'trust-cert')]
    [string]$Command
)

# Set working directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Colors for output
$Host.UI.RawUI.ForegroundColor = "White"

function Write-Success {
    param($Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-Error {
    param($Message)
    Write-Host $Message -ForegroundColor Red
}

function Write-Warning {
    param($Message)
    Write-Host $Message -ForegroundColor Yellow
}

function Show-Banner {
    Write-Host ""
    Write-Success "╔══════════════════════════════════════════╗"
    Write-Success "║          DDALAB Management Tool          ║"
    Write-Success "╚══════════════════════════════════════════╝"
    Write-Host ""
}

function Test-Requirements {
    Write-Host "Checking requirements..."
    
    # Check Docker
    try {
        $null = docker --version
    } catch {
        Write-Error "Error: Docker is not installed"
        Write-Host "Please install Docker Desktop from https://docs.docker.com/desktop/windows/install/"
        exit 1
    }
    
    # Check if Docker daemon is running
    try {
        $null = docker info 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker daemon not running"
        }
    } catch {
        Write-Error "Error: Docker daemon is not running"
        Write-Host "Please start Docker Desktop"
        exit 1
    }
    
    Write-Success "✓ All requirements met"
}

function Initialize-Environment {
    if (-not (Test-Path .env)) {
        Write-Warning "No .env file found. Creating from template..."
        Copy-Item .env.example .env
        
        # Generate secure passwords
        Write-Host "Generating secure passwords..."
        
        # Function to generate password
        function Get-RandomPassword {
            -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 25 | ForEach-Object {[char]$_})
        }
        
        # Read content
        $content = Get-Content .env
        
        # Update passwords
        $content = $content -replace 'DB_PASSWORD=.*', "DB_PASSWORD=$(Get-RandomPassword)"
        $content = $content -replace 'MINIO_ROOT_PASSWORD=.*', "MINIO_ROOT_PASSWORD=$(Get-RandomPassword)"
        $content = $content -replace 'JWT_SECRET_KEY=.*', "JWT_SECRET_KEY=$(Get-RandomPassword)"
        $content = $content -replace 'NEXTAUTH_SECRET=.*', "NEXTAUTH_SECRET=$(Get-RandomPassword)"
        
        # Write back
        $content | Set-Content .env
        
        Write-Success "✓ Environment file created with secure passwords"
        Write-Warning "Please review .env and update any settings as needed"
    } else {
        Write-Success "✓ Environment file exists"
    }
}

function Initialize-SSL {
    if (-not ((Test-Path certs/cert.pem) -and (Test-Path certs/key.pem))) {
        Write-Warning "SSL certificates not found. Generating self-signed certificates..."
        
        # Create certs directory
        New-Item -ItemType Directory -Force -Path certs | Out-Null
        
        # Check if OpenSSL is available
        try {
            $null = openssl version
            
            # Generate self-signed certificate
            $subject = "/C=US/ST=State/L=City/O=Organization/CN=localhost"
            & openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
                -keyout certs/key.pem `
                -out certs/cert.pem `
                -subj $subject 2>$null
                
            Write-Success "✓ SSL certificates generated"
        } catch {
            Write-Error "OpenSSL not found. Please install OpenSSL or manually create certificates"
            Write-Host "You can download OpenSSL from: https://slproweb.com/products/Win32OpenSSL.html"
            Write-Host "Or place your certificates as:"
            Write-Host "  - certs/cert.pem"
            Write-Host "  - certs/key.pem"
            exit 1
        }
    } else {
        Write-Success "✓ SSL certificates exist"
    }
}

function Trust-Certificate {
    if (-not (Test-Path certs/cert.pem)) {
        Write-Error "Certificate not found: certs/cert.pem"
        return
    }

    Write-Host "Setting up certificate trust for Windows..."
    
    try {
        # Check if running as Administrator
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isAdmin) {
            # Convert PEM to X509Certificate2
            $certContent = Get-Content certs/cert.pem -Raw
            $certContent = $certContent -replace "-----BEGIN CERTIFICATE-----", ""
            $certContent = $certContent -replace "-----END CERTIFICATE-----", ""
            $certContent = $certContent -replace "`r", ""
            $certContent = $certContent -replace "`n", ""
            
            $certBytes = [System.Convert]::FromBase64String($certContent)
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
            $cert.Import($certBytes)
            
            # Add to Windows certificate store
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
            $store.Open("ReadWrite")
            
            # Check if certificate already exists
            $existingCert = $store.Certificates | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
            if ($existingCert) {
                Write-Success "✓ Certificate already trusted in Windows certificate store"
            } else {
                $store.Add($cert)
                Write-Success "✓ Certificate added to Windows certificate store"
            }
            $store.Close()
            
        } else {
            Write-Warning "⚠ Not running as Administrator - cannot add to system certificate store"
            Write-Host "To trust the certificate system-wide:"
            Write-Host "1. Run PowerShell as Administrator"
            Write-Host "2. Run: .\ddalab.ps1 trust-cert"
        }
        
    } catch {
        Write-Warning "⚠ Could not add certificate to Windows store: $($_.Exception.Message)"
        Write-Host "Manual certificate import instructions:"
        Write-Host "1. Open Certificate Manager (certmgr.msc)"
        Write-Host "2. Navigate to Trusted Root Certification Authorities > Certificates"
        Write-Host "3. Right-click > All Tasks > Import"
        Write-Host "4. Select certs/cert.pem file"
    }
    
    Write-Host ""
    Write-Host "📋 Browser Trust Instructions:" -ForegroundColor Yellow
    Write-Host "1. Visit https://localhost in your browser"
    Write-Host "2. Click 'Advanced' → 'Proceed to localhost (unsafe)'"
    Write-Host "3. The certificate will be trusted for this session"
    Write-Host ""
}

function Start-Services {
    Write-Host "Starting DDALAB services..."
    
    # Pull latest images
    Write-Host "Pulling latest images..."
    docker compose pull
    
    # Start services
    docker compose up -d
    
    # Wait for services to be ready
    Write-Host "Waiting for services to start..."
    Start-Sleep -Seconds 10
    
    # Check service health
    Write-Host ""
    Write-Host "Service Status:"
    docker compose ps
    
    # Get domain from .env
    $domain = "localhost"
    if (Test-Path .env) {
        $envContent = Get-Content .env | Where-Object { $_ -match "^DOMAIN=" }
        if ($envContent) {
            $domain = $envContent -replace "^DOMAIN=", ""
        }
    }
    
    Write-Host ""
    Write-Success "╔══════════════════════════════════════════════════════════╗"
    Write-Success "║                    DDALAB Started!                       ║"
    Write-Success "╠══════════════════════════════════════════════════════════╣"
    Write-Success "║  Access DDALAB at: https://$domain                      "
    Write-Success "║  MinIO Console at: http://${domain}:9001                 "
    Write-Success "║                                                          ║"
    Write-Success "║  Default credentials:                                    ║"
    Write-Success "║  Email: admin@example.com                                ║"
    Write-Success "║  Password: admin (CHANGE THIS!)                          ║"
    Write-Success "╚══════════════════════════════════════════════════════════╝"
}

function Stop-Services {
    Write-Host "Stopping DDALAB services..."
    docker compose down
    Write-Success "✓ DDALAB stopped"
}

function Show-Logs {
    docker compose logs -f
}

function Show-Status {
    Write-Host "DDALAB Service Status:"
    docker compose ps
}

function Backup-Data {
    Write-Host "Creating backup..."
    if (Test-Path scripts/backup.ps1) {
        & ./scripts/backup.ps1
    } else {
        Write-Warning "Backup script not found. Creating manual backup..."
        
        # Create backup directory
        $backupDir = "backups"
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        
        # Get database credentials from .env
        $dbUser = "ddalab"
        $dbName = "ddalab"
        if (Test-Path .env) {
            $envContent = Get-Content .env
            $userLine = $envContent | Where-Object { $_ -match "^DB_USER=" }
            $nameLine = $envContent | Where-Object { $_ -match "^DB_NAME=" }
            if ($userLine) { $dbUser = $userLine -replace "^DB_USER=", "" }
            if ($nameLine) { $dbName = $nameLine -replace "^DB_NAME=", "" }
        }
        
        # Create backup
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
        $backupFile = "$backupDir/ddalab_backup_$timestamp.sql"
        
        docker compose exec -T postgres pg_dump -U $dbUser $dbName > $backupFile
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Backup created: $backupFile"
        } else {
            Write-Error "Backup failed"
        }
    }
}

function Update-System {
    Write-Warning "Updating DDALAB system..."
    
    # Check if we're in a git repository
    if (-not (Test-Path .git)) {
        Write-Error "Error: Not in a git repository"
        Write-Host "Please navigate to the DDALAB project root directory"
        exit 1
    }
    
    # Check for uncommitted changes
    $gitStatus = git status --porcelain 2>$null
    if ($gitStatus) {
        Write-Warning "Warning: You have uncommitted changes"
        Write-Host "Uncommitted changes:"
        git status --porcelain
        Write-Host ""
        $continue = Read-Host "Continue with update? This may overwrite local changes (y/N)"
        if ($continue -notmatch '^[Yy]$') {
            Write-Host "Update cancelled"
            exit 1
        }
    }
    
    # Save current branch
    $currentBranch = git rev-parse --abbrev-ref HEAD
    Write-Host "Current branch: $currentBranch"
    
    # Pull latest changes
    Write-Host "Pulling latest changes from git..."
    git pull origin $currentBranch
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Error: Git pull failed"
        Write-Host "Please resolve any conflicts manually and run the update again"
        exit 1
    }
    
    Write-Success "✓ Git pull completed successfully"
    
    # Update Docker images and restart services
    Write-Host "Updating Docker images and restarting services..."
    
    # Stop current services
    Write-Host "Stopping current services..."
    docker compose down
    
    # Pull latest images
    Write-Host "Pulling latest Docker images..."
    docker compose pull
    
    # Rebuild and start services
    Write-Host "Rebuilding and starting services..."
    docker compose up -d --build
    
    # Wait for services
    Write-Host "Waiting for services to start..."
    Start-Sleep -Seconds 15
    
    # Show status
    Write-Host ""
    Write-Host "Update completed! Service status:"
    docker compose ps
    
    # Get the domain from .env
    $domain = "localhost"
    if (Test-Path .env) {
        $envContent = Get-Content .env | Where-Object { $_ -match "^DOMAIN=" }
        if ($envContent) {
            $domain = $envContent -replace "^DOMAIN=", ""
        }
    }
    
    Write-Host ""
    Write-Success "╔══════════════════════════════════════════════════════════╗"
    Write-Success "║                  DDALAB Update Complete!                 ║"
    Write-Success "╠══════════════════════════════════════════════════════════╣"
    Write-Success "║  Access DDALAB at: https://$domain                      "
    Write-Success "║  All services have been updated and restarted            ║"
    Write-Success "╚══════════════════════════════════════════════════════════╝"
}

# Main execution
Show-Banner

switch ($Command) {
    'start' {
        Test-Requirements
        Initialize-Environment
        Initialize-SSL
        Start-Services
    }
    'stop' {
        Stop-Services
    }
    'restart' {
        Stop-Services
        Start-Sleep -Seconds 5
        Start-Services
    }
    'update' {
        Test-Requirements
        Update-System
    }
    'logs' {
        Show-Logs
    }
    'status' {
        Show-Status
    }
    'backup' {
        Backup-Data
    }
    default {
        Write-Host "Usage: .\ddalab.ps1 <command>"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  start    - Start DDALAB (sets up environment if needed)"
        Write-Host "  stop     - Stop DDALAB"
        Write-Host "  restart  - Restart DDALAB"
        Write-Host "  update   - Update DDALAB (git pull + rebuild Docker images)"
        Write-Host "  logs     - Show service logs (follow mode)"
        Write-Host "  status   - Show service status"
        Write-Host "  backup   - Create database backup"
    }
}