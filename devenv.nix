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
		odin build src -out:build/debug -debug -extra-linker-flags:"-L${pkgs.sdl3}/lib"
	'';

	scripts.run.exec = ''
		build-debug
		./build/debug
	'';
}
