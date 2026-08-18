{ pkgs, lib, config, inputs, ... }:

{
	languages.odin.enable = true;

	languages.java = {
		enable = true;
		jdk.package = pkgs.jdk8;
		gradle.enable = false;
	};

	packages = [
		pkgs.sdl3
	];

	scripts.build-debug.exec = ''
		odin build src -out:build/debug/squash -debug -extra-linker-flags:"-L${pkgs.sdl3}/lib" -collection:lib=lib
	'';
	scripts.build-release.exec = ''
		odin build src -out:build/release/squash-macos-amd64 -o:aggressive -target:"darwin_amd64" -extra-linker-flags:"-L${pkgs.sdl3}/lib" -collection:lib=lib
		odin build src -out:build/release/squash-linux-amd64 -o:aggressive -target:"linux_amd64" -extra-linker-flags:"-L${pkgs.sdl3}/lib" -collection:lib=lib
		odin build src -out:build/release/squash-windows-amd64.exe -o:aggressive -target:"windows_amd64" -extra-linker-flags:"-L${pkgs.sdl3}/lib" -collection:lib=lib
	'';

	scripts.run.exec = ''
		build-debug
		./build/debug/squash
	'';
}
