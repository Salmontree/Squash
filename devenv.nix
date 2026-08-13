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

	scripts.run.exec = ''
		odin run src -out:build/debug -debug -keep-executable -extra-linker-flags:"-L${pkgs.sdl3}/lib"
	'';
}
