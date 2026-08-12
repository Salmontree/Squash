{
	description = "soietdf";

	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
		flake-utils.url = "github:numtide/flake-utils";
	};

	outputs = { self, nixpkgs, flake-utils }:
		flake-utils.lib.eachDefaultSystem (system:
		let
			pkgs = import nixpkgs { inherit system; };
		in
		{
			devShells.default = pkgs.mkShell {
			buildInputs = with pkgs; [
				odin
				ols
				glfw
				libGL
				libX11
				libXcursor
				libXrandr
				libXinerama
				libXi
				libXext
			];

			# so the odin-compiled binary can find the shared libs at runtime
			LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
				glfw
				libGL
				libX11
				libXcursor
				libXrandr
				libXinerama
				libXi
				libXext
			]);
			};
		});
}
