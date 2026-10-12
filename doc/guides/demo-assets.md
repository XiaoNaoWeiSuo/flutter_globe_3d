# Animated demo assets

These are captures of the real example app, not generated mockups. Original
recordings and GIF masters are kept locally in the ignored directory
`example/recordings/2026-10-12-showcase/`; the README uses GitHub-hosted attachments.
No GIF binaries are added to the Flutter package or Git history.

## Published README resources

| Scene | Size | Playback | Bytes | GitHub attachment |
| --- | --- | --- | --- | --- |
| Live network tour | 480×480 | 20fps, 11.4s, infinite loop | 8,860,033 | [01-live-network.gif](https://github.com/user-attachments/assets/42879e6b-a656-4f0e-bf06-86282ec767b1) |
| Layout & light | 512×512 | 20fps, 9.4s, infinite loop | 5,709,450 | [02-layout-light.gif](https://github.com/user-attachments/assets/a5c577a2-7b36-436b-87a9-6aad66d55d7e) |
| Sphere toolkit | 512×512 | 20fps, 11.4s, infinite loop | 7,113,713 | [03-sphere-toolkit.gif](https://github.com/user-attachments/assets/6248bfe7-fe78-410f-970c-f4d774c9e741) |

SHA-256 of the uploaded files, in scene order:

```text
bddd6dc19a59075291acf6ab74d9dfbdc0998a4aab3ebe22bf8a8918ba6c7531
8b4fd9857a4f8fa4342b67b4647aa5a715434098813834875f9eabc92f5fba5a
40b86f3cba932fa603c62993dc6d17b9160a46022aa8da3d12d87e83bea15f7d
```

The source MP4 clips are square 720×720, 30fps, H.264 and silent. They contain
only the component viewport, with no simulator chrome or controls. Local GIF
masters retain 720×720 at 25fps with a dedicated 256-color palette and
Sierra dithering: `01-live-network.gif`, `02-layout-light.gif` and
`03-sphere-toolkit.gif`. These larger masters exceed GitHub's image upload limit;
the README variants preserve 20fps playback and are downscaled with Lanczos.
The first scene uses 128 colors; the other two use 256. GIF palettes can introduce
banding, especially in atmosphere gradients; use the MP4 or lossless PNGs to
judge native rendering quality.

## Static seven-sphere showcase

The README's linked seven-sphere collage also uses a public GitHub attachment:
[seven-spheres-1-2-4-ultra.png](https://github.com/user-attachments/assets/8df80385-8cef-44c3-b6f9-4d13accf6c73).
Both the image source and its click-through URL are absolute HTTPS URLs, rather
than repository-relative paths. The uploaded asset preserves the original
lossless PNG; the local source remains in
`example/assets/showcase/seven-spheres-1-2-4-ultra.png`. It is associated with the
same public resource issue as the GIFs.

## Reproduce conversion

Run from the recording directory with FFmpeg on PATH. Use a new output filename
to avoid replacing existing masters:

```sh
# High-resolution master. Repeat for each input scene.
ffmpeg -i 01-live-network.mp4 \
  -filter_complex '[0:v]fps=25,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle' \
  -loop 0 01-live-network-master.gif

# README network version, kept below the GitHub attachment size limit.
ffmpeg -i 01-live-network.mp4 \
  -filter_complex '[0:v]fps=20,scale=480:480:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle' \
  -loop 0 01-live-network-readme.gif

# README layout version; use the same settings for 03-sphere-toolkit.mp4.
ffmpeg -i 02-layout-light.mp4 \
  -filter_complex '[0:v]fps=20,scale=512:512:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle' \
  -loop 0 02-layout-light-web.gif
```

## GitHub hosting and wrapping layout

GitHub documents [file attachments](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/attaching-files)
and [CLI attachment uploads](https://docs.github.com/en/github-cli/github-cli/attaching-files-with-github-cli).
Images and GIFs have a 10MB upload limit. A public repository's attachments are
viewable without authentication. Uploading produces a real
`https://github.com/user-attachments/assets/<uuid>` URL; do not invent the UUID
or substitute a local path when publishing.

These files were uploaded through the same media endpoint used by the official
GitHub CLI, associated with `XiaoNaoWeiSuo/flutter_globe_3d`, then referenced in
the authorized public [README demo assets issue](https://github.com/XiaoNaoWeiSuo/flutter_globe_3d/issues/3).
Before public-body association, anonymous requests returned 404 even though
authenticated Markdown rendering could resolve the uploads. Keep the public
asset references; do not assume upload success alone guarantees public access.
No release or code commit was created. If replacing the animations, upload and
associate the new files, verify anonymous access, and update both this manifest
and the README URLs.

The README uses linked HTML images with `width="300"` and alternating
`align="right"` / `align="left"` so surrounding prose wraps alongside them.
`<br clear="all" />` separates each image section from its expandable code example.
No unsupported custom CSS is required. Narrow screens and non-GitHub Markdown
renderers may display the same content vertically instead.

Scene timing and recording reproduction are documented in the
[example README](../../example/README.md); texture credits are in
[SOURCES.md](../../example/assets/textures/SOURCES.md).
