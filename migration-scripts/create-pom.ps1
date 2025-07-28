param (
    [string]$outputPath,
    [string]$packageName = "com.example.api",
    [string]$JavaVersion = "11"
)

# Ensure outputPath is provided
if (-not $outputPath) {
    Write-Host "Error: outputPath parameter is required!" -ForegroundColor Red
    exit 1
}

# Extract group ID and artifact ID from package name
$groupId = if ($packageName -match '^([^.]+\.[^.]+)') { $matches[1] } else { "com.example" }
$artifactId = if ($packageName -match '([^.]+)$') { $matches[1] + "-api" } else { "api" }

# Extract application class name (same logic as create-main-application.ps1)
$appName = if ($packageName -match '([^.]+)$') { 
    $matches[1].Substring(0,1).ToUpper() + $matches[1].Substring(1) + "Application" 
} else { 
    "ApiApplication" 
}

# Create pom.xml
$pomXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.7.8</version>
        <relativePath/>
    </parent>
    
    <groupId>$groupId</groupId>
    <artifactId>$artifactId</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>$artifactId</name>
    <description>API generated from Mule ESB</description>
    
    <properties>
        <java.version>$JavaVersion</java.version>
        <maven.compiler.source>$JavaVersion</maven.compiler.source>
        <maven.compiler.target>$JavaVersion</maven.compiler.target>
        <spring-boot.version>2.7.8</spring-boot.version>
    </properties>
    
    <repositories>
        <repository>
            <id>central</id>
            <name>Maven Central Repository</name>
            <url>https://repo.maven.apache.org/maven2</url>
        </repository>
    </repositories>
    
    <pluginRepositories>
        <pluginRepository>
            <id>central</id>
            <name>Maven Central Repository</name>
            <url>https://repo.maven.apache.org/maven2</url>
        </pluginRepository>
        <pluginRepository>
            <id>spring-releases</id>
            <name>Spring Releases</name>
            <url>https://repo.spring.io/release</url>
        </pluginRepository>
    </pluginRepositories>
    
    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-dependencies</artifactId>
                <version>`${spring-boot.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>
    
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-jdbc</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>
        
        <dependency>
            <groupId>com.h2database</groupId>
            <artifactId>h2</artifactId>
            <scope>runtime</scope>
        </dependency>
        
        <dependency>
            <groupId>org.springdoc</groupId>
            <artifactId>springdoc-openapi-ui</artifactId>
            <version>1.6.14</version>
        </dependency>
        
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
"@

# Write pom file without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$outputPath\pom.xml", $pomXml, $utf8NoBom)

Write-Host "POM file created at: $outputPath\pom.xml"
