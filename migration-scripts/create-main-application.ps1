param (
    [string]$outputPath,
    [string]$packageName = "com.example.api"
)

# Construct main package path
$mainPackagePath = "$outputPath\src\main\java\$($packageName -replace '\.','\\')"

# Ensure directory exists
if (-not (Test-Path $mainPackagePath)) {
    New-Item -ItemType Directory -Force -Path $mainPackagePath | Out-Null
}

# Extract application name from package
$appName = if ($packageName -match '([^.]+)$') { 
    $matches[1].Substring(0,1).ToUpper() + $matches[1].Substring(1) + "Application" 
} else { 
    "Application" 
}

# Create main application class
$applicationClass = @"
package $packageName;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class $appName {
    public static void main(String[] args) {
        SpringApplication.run($appName.class, args);
    }
}
"@

# Write application file without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$mainPackagePath\$appName.java", $applicationClass, $utf8NoBom)

Write-Host "Main application class created at: $mainPackagePath\$appName.java"
