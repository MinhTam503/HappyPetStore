# Clean Architecture Migration Script

$refactorLog = @()

# Function to update imports in a file
function Update-Imports {
    param(
        [string]$FilePath,
        [hashtable]$ImportMappings
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "File not found: $FilePath" -ForegroundColor Yellow
        return
    }
    
    $content = Get-Content $FilePath -Raw
    $originalContent = $content
    $changed = $false
    
    foreach ($oldImport in $ImportMappings.Keys) {
        $newImport = $ImportMappings[$oldImport]
        if ($content -match [regex]::Escape($oldImport)) {
            $content = $content -replace [regex]::Escape($oldImport), $newImport
            $changed = $true
            Write-Host "Updated import in $FilePath`: $oldImport -> $newImport" -ForegroundColor Green
        }
    }
    
    if ($changed) {
        Set-Content $FilePath $content -NoNewline
        $script:refactorLog += "Updated imports in: $FilePath"
    }
}

# Define import mappings
$importMappings = @{
    "package:pet_shop/utils/contants.dart" = "package:pet_shop/core/constants/app_constants.dart"
    "package:pet_shop/utils/dialog_helper.dart" = "package:pet_shop/core/utils/dialog_helper.dart"
    "package:pet_shop/utils/responsive_utils.dart" = "package:pet_shop/core/utils/responsive_utils.dart"
    "package:pet_shop/utils/firebase_debug.dart" = "package:pet_shop/core/utils/firebase_debug.dart"
    "package:pet_shop/utils/list_city.dart" = "package:pet_shop/core/constants/list_city.dart"
    "package:pet_shop/providers/" = "package:pet_shop/core/providers/"
    "package:pet_shop/l10n/" = "package:pet_shop/core/localization/"
    "package:pet_shop/bloc/" = "package:pet_shop/presentation/bloc/"
    "package:pet_shop/widgets/" = "package:pet_shop/presentation/widgets/"
    "package:pet_shop/components/" = "package:pet_shop/presentation/widgets/components/"
    "package:pet_shop/view/" = "package:pet_shop/presentation/pages/"
    "package:pet_shop/services/payment_service.dart" = "package:pet_shop/data/datasources/remote/payment_service.dart"
    "package:pet_shop/services/stripe_checkout" = "package:pet_shop/data/datasources/remote/stripe_checkout"
    "package:pet_shop/services/apriori/" = "package:pet_shop/data/datasources/local/apriori/"
}

# Get all Dart files
$dartFiles = Get-ChildItem -Path "d:\Subjects\FinalReport\project\pet_shop\lib" -Recurse -Filter "*.dart"

Write-Host "Starting import refactoring for $($dartFiles.Count) Dart files..." -ForegroundColor Cyan

foreach ($file in $dartFiles) {
    Update-Imports -FilePath $file.FullName -ImportMappings $importMappings
}

# Output summary
Write-Host "`nRefactoring Summary:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
$refactorLog | ForEach-Object { Write-Host $_ -ForegroundColor Green }

Write-Host "`nClean Architecture migration completed!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Fix any remaining import errors" -ForegroundColor Yellow
Write-Host "2. Run 'flutter pub get'" -ForegroundColor Yellow  
Write-Host "3. Run 'flutter analyze' to check for issues" -ForegroundColor Yellow
Write-Host "4. Test the application" -ForegroundColor Yellow
