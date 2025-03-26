#!/bin/bash

echo "Janet Xcode Project Creator"
echo "=========================="
echo

# Define paths
JANET_DIR="/Volumes/Folk_DAS/Janet_25"
SOURCE_DIR="$JANET_DIR/Source"
TEMPLATE_DIR="$JANET_DIR/xcode_template"
PROJECT_NAME="Janet"
ORGANIZATION_ID="com.FolkAI"

# Check if Source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory not found at $SOURCE_DIR"
    exit 1
fi

# Create template directory if it doesn't exist
mkdir -p "$TEMPLATE_DIR"

echo "This script will help you create a new Xcode project for Janet."
echo "It will create a project that matches the existing app structure."
echo

# Step 1: Create Info.plist template
echo "Step 1: Creating Info.plist template..."

cat > "$TEMPLATE_DIR/Info.plist" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>com.FolkAI.Janet</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 FolkAI. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOL

echo "Info.plist template created."

# Step 2: Create entitlements file
echo
echo "Step 2: Creating entitlements file..."

cat > "$TEMPLATE_DIR/Janet.entitlements" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
</dict>
</plist>
EOL

echo "Entitlements file created."

# Step 3: Create a script to generate the Xcode project
echo
echo "Step 3: Creating Xcode project generator script..."

cat > "$JANET_DIR/generate_xcode_project.swift" << EOL
#!/usr/bin/swift

import Foundation

// Define paths
let janetDir = "/Volumes/Folk_DAS/Janet_25"
let sourceDir = "\(janetDir)/Source"
let projectName = "Janet"
let organizationID = "com.FolkAI"

// Create project directory
let projectDir = "\(janetDir)/\(projectName).xcodeproj"
try? FileManager.default.createDirectory(atPath: projectDir, withIntermediateDirectories: true)

// Create basic project.pbxproj file
let projectContent = """
// !$*UTF8*$!
{
    archiveVersion = 1;
    classes = {
    };
    objectVersion = 56;
    objects = {

/* Begin PBXBuildFile section */
        1A2B3C4D5E6F7G8H /* JanetApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = 8H7G6F5E4D3C2B1A /* JanetApp.swift */; };
        2B3C4D5E6F7G8H9I /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = 9I8H7G6F5E4D3C2B /* Assets.xcassets */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
        0A1B2C3D4E5F6G7H /* Janet.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Janet.app; sourceTree = BUILT_PRODUCTS_DIR; };
        8H7G6F5E4D3C2B1A /* JanetApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = JanetApp.swift; sourceTree = "<group>"; };
        9I8H7G6F5E4D3C2B /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };
        A1B2C3D4E5F6G7H8 /* Janet.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Janet.entitlements; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
        B2C3D4E5F6G7H8I9 /* Frameworks */ = {
            isa = PBXFrameworksBuildPhase;
            buildActionMask = 2147483647;
            files = (
            );
            runOnlyForDeploymentPostprocessing = 0;
        };
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
        C3D4E5F6G7H8I9J0 = {
            isa = PBXGroup;
            children = (
                D4E5F6G7H8I9J0K1 /* Source */,
                E5F6G7H8I9J0K1L2 /* Products */,
            );
            sourceTree = "<group>";
        };
        E5F6G7H8I9J0K1L2 /* Products */ = {
            isa = PBXGroup;
            children = (
                0A1B2C3D4E5F6G7H /* Janet.app */,
            );
            name = Products;
            sourceTree = "<group>";
        };
        D4E5F6G7H8I9J0K1 /* Source */ = {
            isa = PBXGroup;
            children = (
                8H7G6F5E4D3C2B1A /* JanetApp.swift */,
                9I8H7G6F5E4D3C2B /* Assets.xcassets */,
                A1B2C3D4E5F6G7H8 /* Janet.entitlements */,
            );
            path = Source;
            sourceTree = "<group>";
        };
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
        F6G7H8I9J0K1L2M3 /* Janet */ = {
            isa = PBXNativeTarget;
            buildConfigurationList = G7H8I9J0K1L2M3N4 /* Build configuration list for PBXNativeTarget "Janet" */;
            buildPhases = (
                H8I9J0K1L2M3N4O5 /* Sources */,
                B2C3D4E5F6G7H8I9 /* Frameworks */,
                I9J0K1L2M3N4O5P6 /* Resources */,
            );
            buildRules = (
            );
            dependencies = (
            );
            name = Janet;
            productName = Janet;
            productReference = 0A1B2C3D4E5F6G7H /* Janet.app */;
            productType = "com.apple.product-type.application";
        };
/* End PBXNativeTarget section */

/* Begin PBXProject section */
        J0K1L2M3N4O5P6Q7 /* Project object */ = {
            isa = PBXProject;
            attributes = {
                BuildIndependentTargetsInParallel = 1;
                LastSwiftUpdateCheck = 1620;
                LastUpgradeCheck = 1620;
                ORGANIZATIONNAME = FolkAI;
                TargetAttributes = {
                    F6G7H8I9J0K1L2M3 = {
                        CreatedOnToolsVersion = 16.2;
                    };
                };
            };
            buildConfigurationList = K1L2M3N4O5P6Q7R8 /* Build configuration list for PBXProject "Janet" */;
            compatibilityVersion = "Xcode 14.0";
            developmentRegion = en;
            hasScannedForEncodings = 0;
            knownRegions = (
                en,
                Base,
            );
            mainGroup = C3D4E5F6G7H8I9J0;
            productRefGroup = E5F6G7H8I9J0K1L2 /* Products */;
            projectDirPath = "";
            projectRoot = "";
            targets = (
                F6G7H8I9J0K1L2M3 /* Janet */,
            );
        };
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
        I9J0K1L2M3N4O5P6 /* Resources */ = {
            isa = PBXResourcesBuildPhase;
            buildActionMask = 2147483647;
            files = (
                2B3C4D5E6F7G8H9I /* Assets.xcassets in Resources */,
            );
            runOnlyForDeploymentPostprocessing = 0;
        };
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
        H8I9J0K1L2M3N4O5 /* Sources */ = {
            isa = PBXSourcesBuildPhase;
            buildActionMask = 2147483647;
            files = (
                1A2B3C4D5E6F7G8H /* JanetApp.swift in Sources */,
            );
            runOnlyForDeploymentPostprocessing = 0;
        };
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
        L2M3N4O5P6Q7R8S9 /* Debug */ = {
            isa = XCBuildConfiguration;
            buildSettings = {
                ALWAYS_SEARCH_USER_PATHS = NO;
                ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
                CLANG_ANALYZER_NONNULL = YES;
                CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
                CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
                CLANG_ENABLE_MODULES = YES;
                CLANG_ENABLE_OBJC_ARC = YES;
                CLANG_ENABLE_OBJC_WEAK = YES;
                CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
                CLANG_WARN_BOOL_CONVERSION = YES;
                CLANG_WARN_COMMA = YES;
                CLANG_WARN_CONSTANT_CONVERSION = YES;
                CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
                CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
                CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
                CLANG_WARN_EMPTY_BODY = YES;
                CLANG_WARN_ENUM_CONVERSION = YES;
                CLANG_WARN_INFINITE_RECURSION = YES;
                CLANG_WARN_INT_CONVERSION = YES;
                CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
                CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
                CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
                CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
                CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
                CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
                CLANG_WARN_STRICT_PROTOTYPES = YES;
                CLANG_WARN_SUSPICIOUS_MOVE = YES;
                CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
                CLANG_WARN_UNREACHABLE_CODE = YES;
                CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
                COPY_PHASE_STRIP = NO;
                DEBUG_INFORMATION_FORMAT = dwarf;
                ENABLE_STRICT_OBJC_MSGSEND = YES;
                ENABLE_TESTABILITY = YES;
                ENABLE_USER_SCRIPT_SANDBOXING = YES;
                GCC_C_LANGUAGE_STANDARD = gnu17;
                GCC_DYNAMIC_NO_PIC = NO;
                GCC_NO_COMMON_BLOCKS = YES;
                GCC_OPTIMIZATION_LEVEL = 0;
                GCC_PREPROCESSOR_DEFINITIONS = (
                    "DEBUG=1",
                    "$(inherited)",
                );
                GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
                GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
                GCC_WARN_UNDECLARED_SELECTOR = YES;
                GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
                GCC_WARN_UNUSED_FUNCTION = YES;
                GCC_WARN_UNUSED_VARIABLE = YES;
                LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
                MACOSX_DEPLOYMENT_TARGET = 14.0;
                MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
                MTL_FAST_MATH = YES;
                ONLY_ACTIVE_ARCH = YES;
                SDKROOT = macosx;
                SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
                SWIFT_OPTIMIZATION_LEVEL = "-Onone";
            };
            name = Debug;
        };
        M3N4O5P6Q7R8S9T0 /* Release */ = {
            isa = XCBuildConfiguration;
            buildSettings = {
                ALWAYS_SEARCH_USER_PATHS = NO;
                ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
                CLANG_ANALYZER_NONNULL = YES;
                CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
                CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
                CLANG_ENABLE_MODULES = YES;
                CLANG_ENABLE_OBJC_ARC = YES;
                CLANG_ENABLE_OBJC_WEAK = YES;
                CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
                CLANG_WARN_BOOL_CONVERSION = YES;
                CLANG_WARN_COMMA = YES;
                CLANG_WARN_CONSTANT_CONVERSION = YES;
                CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
                CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
                CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
                CLANG_WARN_EMPTY_BODY = YES;
                CLANG_WARN_ENUM_CONVERSION = YES;
                CLANG_WARN_INFINITE_RECURSION = YES;
                CLANG_WARN_INT_CONVERSION = YES;
                CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
                CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
                CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
                CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
                CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
                CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
                CLANG_WARN_STRICT_PROTOTYPES = YES;
                CLANG_WARN_SUSPICIOUS_MOVE = YES;
                CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
                CLANG_WARN_UNREACHABLE_CODE = YES;
                CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
                COPY_PHASE_STRIP = NO;
                DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
                ENABLE_NS_ASSERTIONS = NO;
                ENABLE_STRICT_OBJC_MSGSEND = YES;
                ENABLE_USER_SCRIPT_SANDBOXING = YES;
                GCC_C_LANGUAGE_STANDARD = gnu17;
                GCC_NO_COMMON_BLOCKS = YES;
                GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
                GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
                GCC_WARN_UNDECLARED_SELECTOR = YES;
                GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
                GCC_WARN_UNUSED_FUNCTION = YES;
                GCC_WARN_UNUSED_VARIABLE = YES;
                LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
                MACOSX_DEPLOYMENT_TARGET = 14.0;
                MTL_ENABLE_DEBUG_INFO = NO;
                MTL_FAST_MATH = YES;
                SDKROOT = macosx;
                SWIFT_COMPILATION_MODE = wholemodule;
            };
            name = Release;
        };
        N4O5P6Q7R8S9T0U1 /* Debug */ = {
            isa = XCBuildConfiguration;
            buildSettings = {
                ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
                ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
                CODE_SIGN_ENTITLEMENTS = Source/Janet.entitlements;
                CODE_SIGN_STYLE = Automatic;
                COMBINE_HIDPI_IMAGES = YES;
                CURRENT_PROJECT_VERSION = 1;
                DEVELOPMENT_ASSET_PATHS = "";
                ENABLE_PREVIEWS = YES;
                GENERATE_INFOPLIST_FILE = YES;
                INFOPLIST_FILE = Source/Info.plist;
                INFOPLIST_KEY_NSHumanReadableCopyright = "Copyright © 2024 FolkAI. All rights reserved.";
                LD_RUNPATH_SEARCH_PATHS = (
                    "$(inherited)",
                    "@executable_path/../Frameworks",
                );
                MARKETING_VERSION = 1.0;
                PRODUCT_BUNDLE_IDENTIFIER = com.FolkAI.Janet;
                PRODUCT_NAME = "$(TARGET_NAME)";
                SWIFT_EMIT_LOC_STRINGS = YES;
                SWIFT_VERSION = 5.0;
            };
            name = Debug;
        };
        O5P6Q7R8S9T0U1V2 /* Release */ = {
            isa = XCBuildConfiguration;
            buildSettings = {
                ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
                ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
                CODE_SIGN_ENTITLEMENTS = Source/Janet.entitlements;
                CODE_SIGN_STYLE = Automatic;
                COMBINE_HIDPI_IMAGES = YES;
                CURRENT_PROJECT_VERSION = 1;
                DEVELOPMENT_ASSET_PATHS = "";
                ENABLE_PREVIEWS = YES;
                GENERATE_INFOPLIST_FILE = YES;
                INFOPLIST_FILE = Source/Info.plist;
                INFOPLIST_KEY_NSHumanReadableCopyright = "Copyright © 2024 FolkAI. All rights reserved.";
                LD_RUNPATH_SEARCH_PATHS = (
                    "$(inherited)",
                    "@executable_path/../Frameworks",
                );
                MARKETING_VERSION = 1.0;
                PRODUCT_BUNDLE_IDENTIFIER = com.FolkAI.Janet;
                PRODUCT_NAME = "$(TARGET_NAME)";
                SWIFT_EMIT_LOC_STRINGS = YES;
                SWIFT_VERSION = 5.0;
            };
            name = Release;
        };
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
        K1L2M3N4O5P6Q7R8 /* Build configuration list for PBXProject "Janet" */ = {
            isa = XCConfigurationList;
            buildConfigurations = (
                L2M3N4O5P6Q7R8S9 /* Debug */,
                M3N4O5P6Q7R8S9T0 /* Release */,
            );
            defaultConfigurationIsVisible = 0;
            defaultConfigurationName = Release;
        };
        G7H8I9J0K1L2M3N4 /* Build configuration list for PBXNativeTarget "Janet" */ = {
            isa = XCConfigurationList;
            buildConfigurations = (
                N4O5P6Q7R8S9T0U1 /* Debug */,
                O5P6Q7R8S9T0U1V2 /* Release */,
            );
            defaultConfigurationIsVisible = 0;
            defaultConfigurationName = Release;
        };
/* End XCConfigurationList section */
    };
    rootObject = J0K1L2M3N4O5P6Q7 /* Project object */;
}
"""

// Write project.pbxproj file
let projectFilePath = "\(projectDir)/project.pbxproj"
try projectContent.write(toFile: projectFilePath, atomically: true, encoding: .utf8)

print("Basic Xcode project created at: \(projectDir)")
print("Next steps:")
print("1. Open the project in Xcode")
print("2. Add the Source files to the project")
print("3. Add the SQLite.swift package (version 0.14.1)")
print("4. Build and run the app")
EOL

chmod +x "$JANET_DIR/generate_xcode_project.swift"
echo "Xcode project generator script created."

# Step 4: Create Info.plist in Source directory
echo
echo "Step 4: Creating Info.plist in Source directory..."

if [ ! -f "$SOURCE_DIR/Info.plist" ]; then
    cp "$TEMPLATE_DIR/Info.plist" "$SOURCE_DIR/Info.plist"
    echo "Info.plist created in Source directory."
else
    echo "Info.plist already exists in Source directory."
fi

# Step 5: Create entitlements file in Source directory
echo
echo "Step 5: Creating entitlements file in Source directory..."

if [ ! -f "$SOURCE_DIR/Janet.entitlements" ]; then
    cp "$TEMPLATE_DIR/Janet.entitlements" "$SOURCE_DIR/Janet.entitlements"
    echo "Janet.entitlements created in Source directory."
else
    echo "Janet.entitlements already exists in Source directory."
fi

echo
echo "Setup complete!"
echo
echo "To create a new Xcode project:"
echo "1. Run the generator script: ./generate_xcode_project.swift"
echo "2. Open the generated project in Xcode"
echo "3. Add the Source files to the project"
echo "4. Add the SQLite.swift package (version 0.14.1)"
echo "5. Run the entitlements fix script: ./fix_entitlements.sh"
echo "6. Build and run the app"
echo
echo "For detailed instructions, refer to the README.txt file."

# Step 6: Create fix_entitlements.sh script if it doesn't exist
echo
echo "Step 6: Creating entitlements fix script..."

if [ ! -f "$JANET_DIR/fix_entitlements.sh" ]; then
    cat > "$JANET_DIR/fix_entitlements.sh" << 'EOL'
#!/bin/bash

# fix_entitlements.sh
# Script to fix entitlements issues in the Janet Xcode project

echo "Janet Entitlements Fix Script"
echo "============================"
echo

# Set the base directory
BASE_DIR="/Volumes/Folk_DAS/Janet_25"
cd "$BASE_DIR" || { echo "Error: Cannot change to $BASE_DIR directory"; exit 1; }

# Create Janet directory if it doesn't exist
if [ ! -d "$BASE_DIR/Janet" ]; then
    echo "Creating Janet directory..."
    mkdir -p "$BASE_DIR/Janet"
    echo "✅ Janet directory created"
else
    echo "✅ Janet directory already exists"
fi

# Copy entitlements file if it doesn't exist in Janet directory
if [ ! -f "$BASE_DIR/Janet/Janet.entitlements" ]; then
    if [ -f "$BASE_DIR/Janet.entitlements" ]; then
        echo "Copying entitlements file to Janet directory..."
        cp "$BASE_DIR/Janet.entitlements" "$BASE_DIR/Janet/"
        echo "✅ Entitlements file copied"
    elif [ -f "$BASE_DIR/Source/Janet.entitlements" ]; then
        echo "Copying entitlements file from Source directory..."
        cp "$BASE_DIR/Source/Janet.entitlements" "$BASE_DIR/Janet/"
        echo "✅ Entitlements file copied from Source directory"
    else
        echo "❌ Error: Janet.entitlements file not found"
        exit 1
    fi
else
    echo "✅ Entitlements file already exists in Janet directory"
fi

# Copy source files if they don't exist
if [ ! -f "$BASE_DIR/Janet/JanetApp.swift" ]; then
    echo "Copying source files to Janet directory..."
    cp -r "$BASE_DIR/Source/"* "$BASE_DIR/Janet/"
    echo "✅ Source files copied"
else
    echo "✅ Source files already exist in Janet directory"
fi

# Verify the structure
echo
echo "Verifying project structure..."
if [ -f "$BASE_DIR/Janet/Janet.entitlements" ] && [ -f "$BASE_DIR/Janet/JanetApp.swift" ]; then
    echo "✅ Project structure is correct"
    echo
    echo "The entitlements issue has been fixed. You can now build the project in Xcode."
    echo "If you still encounter issues, try cleaning the build folder (Product > Clean Build Folder) and rebuilding."
else
    echo "❌ Error: Project structure verification failed"
    echo "Please check the project structure manually."
fi

echo
echo "Done!"
EOL
    chmod +x "$JANET_DIR/fix_entitlements.sh"
    echo "Entitlements fix script created and made executable."
else
    echo "Entitlements fix script already exists."
fi 