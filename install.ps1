# Install dependencies
Write-Host "Installing Python dependencies..." -ForegroundColor Green
pip install -r requirements.txt

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nDependencies installed successfully!" -ForegroundColor Green
    Write-Host "`nTo run the application, execute:" -ForegroundColor Yellow
    Write-Host "python app.py" -ForegroundColor Cyan
} else {
    Write-Host "`nError installing dependencies!" -ForegroundColor Red
}
