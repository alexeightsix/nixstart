# The Android SDK, pinned to what the Expo project on this machine builds
# against rather than to "latest".
#
# There was no Android toolchain here at all — no SDK, no adb, no JDK — so
# `expo start` warned "Failed to resolve the Android SDK path. Default install
# location not found: ~/Android/sdk", fell back to a bare `adb` that also did
# not exist, and died with `spawn adb ENOENT`. Expo looks at $ANDROID_HOME,
# then the deprecated $ANDROID_SDK_ROOT, then ~/Android/sdk, and runs
# $ANDROID_HOME/platform-tools/adb; lib/dev-env.nix sets the first of those to
# this derivation.
#
# Every version below is a requirement read out of the project, not a
# preference. `expo prebuild` generates a build.gradle from these, and a
# mismatch is a build failure rather than a warning:
#
#   platform 36        expo-modules-core's gradle plugin defaults
#   build-tools 36.0.0   compileSdkVersion/targetSdkVersion to 36
#   ndk 27.1.12297006  react-native 0.81's ndkVersion, exactly
#   cmake 3.22.1       the version AGP's externalNativeBuild asks the SDK for
#
# So this is deliberately not `latest` on any of them: nixpkgs currently
# carries platform 37.1, build-tools 37.0.0 and NDK 29, and taking those would
# build an SDK the project cannot use. Bumping Expo is what moves these.
#
# Only the x86_64 system image is fetched, and only google_apis_playstore.
# Every image is a separate multi-gigabyte download, the emulator runs on
# this machine's own KVM rather than emulating ARM, and Play Services are
# needed for anything that touches location — which this project does.
#
# Nothing here has a system half, which is worth saying because adding one is
# the obvious next edit.
#
#   A phone over USB needs no udev rule and no `programs.adb.enable`. nixpkgs
#   has removed android-udev-rules as superseded, and systemd's own
#   70-uaccess.rules now recognises the ADB and Fastboot interface classes,
#   sets ID_DEBUG_APPLIANCE=android on them and tags that uaccess — so the
#   device belongs to whoever is logged in at the seat, with no adbusers group
#   in it. Turning `programs.adb.enable` on would contribute nothing but a
#   second adb, from pkgs.android-tools, which is the one thing worth avoiding
#   here: two adb binaries of different versions on one PATH spend their time
#   killing each other's daemon.
#
#   The emulator needs no group either — /dev/kvm is already 0666.
{
  androidenv,
}:
let
  platformVersion = "36";
  buildToolsVersion = "36.0.0";
  ndkVersion = "27.1.12297006";
  cmakeVersion = "3.22.1";

  composition = androidenv.composeAndroidPackages {
    platformVersions = [ platformVersion ];
    buildToolsVersions = [ buildToolsVersion ];
    ndkVersions = [ ndkVersion ];
    cmakeVersions = [ cmakeVersion ];

    includeNDK = true;
    includeCmake = true;
    includeEmulator = true;
    includeSystemImages = true;
    systemImageTypes = [ "google_apis_playstore" ];
    abiVersions = [ "x86_64" ];

    # Android platform sources are for stepping into framework code in a
    # debugger. Another gigabyte for something nothing here does.
    includeSources = false;
  };

  sdk = composition.androidsdk;

  # composeAndroidPackages assembles the SDK under libexec and symlinks the
  # common executables — adb, emulator, avdmanager, sdkmanager — into bin/.
  # ANDROID_HOME has to be the former: Expo and Gradle both join paths onto
  # it (platform-tools/adb, build-tools/<v>/aapt2) and neither exists in bin/.
  root = "${sdk}/libexec/android-sdk";
in
{
  inherit
    sdk
    root
    platformVersion
    buildToolsVersion
    ndkVersion
    ;

  ndkRoot = "${root}/ndk/${ndkVersion}";

  # The one thing that does not work out of the box on NixOS.
  #
  # The Android Gradle Plugin does not use the aapt2 in the SDK. It resolves
  # its own from Maven as a jar, unpacks a prebuilt ELF out of it and execs
  # that — a dynamically linked binary against paths no NixOS machine has, so
  # every resource-linking task fails with ENOENT on the interpreter. AGP
  # reads this property to be pointed at a real one instead, and the SDK's
  # build-tools binaries are patched for this system.
  aapt2 = "${root}/build-tools/${buildToolsVersion}/aapt2";
}
