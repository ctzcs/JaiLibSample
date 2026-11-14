# Preview textures

Place PNG, JPEG, or QOI images here. Shader Lab's texture controls load the
selected file immediately and preserve the previous texture if loading fails.
An empty path uses the built-in checkerboard texture.

Image paths in `.oshader` parameter defaults are relative to `shaders/`, for
example `image = "textures/noise.png"`. Changing a preview texture does not rewrite
the shader source. The host's file dialog also accepts absolute paths.
