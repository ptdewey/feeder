{ lib, stdenv, beam28Packages, gleam }:

stdenv.mkDerivation rec {
  pname = "feeder";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ beam28Packages.erlang beam28Packages.rebar3 gleam ];

  buildPhase = ''
    export HOME=$TMPDIR
    gleam build --target erlang
  '';

  installPhase = ''
    mkdir -p $out/bin $out/lib

    # Copy all built Erlang packages
    cp -r build/dev/erlang/* $out/lib/

    # Create wrapper script
    cat > $out/bin/${pname} <<WRAPPER
    #!/usr/bin/env bash
    exec ${beam28Packages.erlang}/bin/erl \
      -pa $out/lib/*/ebin \
      -noshell \
      -eval 'feeder:main().'
    WRAPPER
    chmod +x $out/bin/${pname}
  '';

  meta = with lib; {
    description = "RSS/Atom feed aggregator";
    platforms = platforms.unix;
  };
}
