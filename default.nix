with import <nixpkgs> {};

let

  version = "1.22.1";

  unfreeConfig = config.nixpkgs.config // {
    allowUnfree = true;
  };

  rpath = stdenv.lib.makeLibraryPath [
    alsaLib
    atk
    at-spi2-core
    at-spi2-atk
    libsecret
    cairo
    cups
    curl
    dbus
    expat
    fontconfig
    freetype
    glib
    gnome2.GConf
    gnome2.gdk_pixbuf
    gnome3.gtk
    gnome2.pango
    libnotify
    xorg.libxcb
    libuuid
    nspr
    nss
    stdenv.cc.cc
    systemd

    xorg.libxkbfile
    xorg.libX11
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXtst
    xorg.libXScrnSaver
  ] + ":${stdenv.cc.cc.lib}/lib64";

  src =
    if stdenv.hostPlatform.system == "x86_64-linux" then
      fetchurl {
        url = "https://downloads.mongodb.com/compass/mongodb-compass_${version}_amd64.deb";
        sha256 = "a9e50002e2529e629a62a838e009c47e14aa36b5bcee7c292126c646b89072f1";
      }
    else
      throw "MongoDB compass is not supported on ${stdenv.hostPlatform.system}";

in stdenv.mkDerivation {
  pname = "mongodb-compass";
  inherit version;

  inherit src;

  buildInputs = [ dpkg wrapGAppsHook gnome3.gtk ];
  dontUnpack = true;

  buildCommand = ''
    IFS=$'\n'

    mkdir -p $out

    #dpkg -x $src .
    dpkg --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner
    cp -av usr/* $out
    rm -rf $out/share/lintian
    #The node_modules are bringing in non-linux files/dependencies
    find $out -name "*.app" -exec rm -rf {} \; || true
    find $out -name "*.dll" -delete
    find $out -name "*.exe" -delete
    # Otherwise it looks "suspicious"
    chmod -R g-w $out
    for file in `find $out -type f -perm /0111 -o -name \*.so\*`; do
      echo "Manipulating file: $file"
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" || true
      patchelf --set-rpath ${rpath}:$out/share/mongodb-compass::$out/lib/mongodb-compass "$file" || true
    done
    wrapGAppsHook $out/bin/mongodb-compass
  '';

  meta = with stdenv.lib; {
    description = "The GUI for MongoDB";
    homepage = "https://www.mongodb.com/products/compass";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
