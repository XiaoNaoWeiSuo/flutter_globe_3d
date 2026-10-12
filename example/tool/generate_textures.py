"""Generate original antialiased 2048x1024 PNG demo textures (MIT).

Run: python3 example/tool/generate_textures.py (requires numpy and Pillow).
Vector artwork is drawn at 4x resolution; spherical patterns at 2x, then
Lanczos downsampled. Soccer panels are a ray projection of a truncated
icosahedron, rather than a flat approximation or an enlarged small bitmap.
"""
from itertools import combinations
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'textures'
W, H = 2048, 1024


def save(name, image):
    image.resize((W, H), Image.Resampling.LANCZOS).save(OUT / f'{name}.png', optimize=True)


def face(name, wink=False):
    scale = 8  # relative to the original 1024x512 drawing coordinates
    image = Image.new('RGB', (1024 * scale, 512 * scale), '#ffce35')
    draw = ImageDraw.Draw(image)
    def box(values): return tuple(int(n * scale) for n in values)
    ink = '#33231b'
    draw.ellipse(box((442, 204, 466, 238)), fill=ink)
    if wink:
        draw.arc(box((552, 208, 590, 236)), 185, 355, fill=ink, width=7 * scale)
    else:
        draw.ellipse(box((558, 204, 582, 238)), fill=ink)
    draw.arc(box((452, 218, 572, 300)), 10, 170, fill=ink, width=9 * scale)
    for cx in (426, 598):
        draw.ellipse(box((cx - 15, 250, cx + 15, 266)), fill='#f89453')
    save(name, image)


def ico_planes():
    phi = (1 + np.sqrt(5)) / 2
    vertices = np.array([(0, a, b * phi) for a in (-1, 1) for b in (-1, 1)] +
                        [(a, b * phi, 0) for a in (-1, 1) for b in (-1, 1)] +
                        [(b * phi, 0, a) for a in (-1, 1) for b in (-1, 1)])
    vertices /= np.linalg.norm(vertices[0])
    distances = np.linalg.norm(vertices[:, None] - vertices[None, :], axis=2)
    edge = np.min(distances[distances > 0.01])
    neighbors = np.isclose(distances, edge)
    planes = []
    for i, vertex in enumerate(vertices):
        neighbor = vertices[np.flatnonzero(neighbors[i])[0]]
        offset = np.dot(vertex, (2 * vertex + neighbor) / 3)
        planes.append(vertex / offset)
    for i, j, k in combinations(range(12), 3):
        if neighbors[i, j] and neighbors[i, k] and neighbors[j, k]:
            normal = vertices[i] + vertices[j] + vertices[k]
            normal /= np.linalg.norm(normal)
            planes.append(normal / np.dot(normal, vertices[i]))
    assert len(planes) == 32
    return np.array(planes)


def spherical(name):
    width, height = W * 2, H * 2
    image = Image.new('RGB', (width, height))
    longitude = ((np.arange(width) + 0.5) / width - 0.5) * 2 * np.pi
    planes = ico_planes() if name == 'soccer' else None
    # Work in strips to keep regeneration memory bounded.
    for start in range(0, height, 64):
        latitude = (0.5 - (np.arange(start, min(start + 64, height)) + 0.5) / height) * np.pi
        x = np.cos(latitude[:, None]) * np.sin(longitude)
        y = np.broadcast_to(np.sin(latitude[:, None]), x.shape)
        z = np.cos(latitude[:, None]) * np.cos(longitude)
        if name == 'basketball':
            distance = np.minimum.reduce([np.abs(y), np.abs(x), np.abs((x + z) / np.sqrt(2)), np.abs((x - z) / np.sqrt(2))])
            # Lower-frequency surface detail avoids the old high-frequency moire.
            pebble = np.sin(95 * x + 5 * np.sin(23 * z)) * np.sin(95 * y + 9 * z)
            base = np.array([213, 102, 29]) + pebble[..., None] * 8
            channel = np.clip((0.016 - distance) / 0.003, 0, 1)[..., None]
            pixels = base * (1 - channel) + np.array([38, 25, 19]) * channel
        elif name == 'billiard':
            pixels = np.broadcast_to([25., 28., 34.], (*x.shape, 3)).copy()
            pixels[np.abs(z) > 0.91] = [241, 237, 218]
        else:
            scores = np.stack([x, y, z], axis=-1) @ planes.T
            face_id = np.argmax(scores, axis=-1)
            top_two = np.partition(scores, -2, axis=-1)[..., -2:]
            seam = (top_two[..., 1] - top_two[..., 0]) < 0.006
            pixels = np.broadcast_to([236., 237., 235.], (*x.shape, 3)).copy()
            pixels[face_id < 12] = [27, 30, 33]
            pixels[seam] = [65, 68, 70]
        image.paste(Image.fromarray(np.uint8(np.clip(pixels, 0, 255))), (0, start))
    if name == 'billiard':
        draw = ImageDraw.Draw(image)
        scale = width / 1024
        for cx in (512, 0, 1024):
            for box in [(cx - 12, 228, cx + 12, 258), (cx - 14, 252, cx + 14, 284)]:
                draw.ellipse(tuple(int(n * scale) for n in box), outline='#202329', width=int(6 * scale))
    save(name, image)


def uv_checker():
    scale = 8
    image = Image.new('RGB', (1024 * scale, 512 * scale))
    draw = ImageDraw.Draw(image)
    for row in range(8):
        for col in range(16):
            color = (45 + col * 11, 65 + row * 20, 180) if (row + col) % 2 else (231, 235, 240)
            box = (col * 64 * scale, row * 64 * scale, (col + 1) * 64 * scale - 1, (row + 1) * 64 * scale - 1)
            draw.rectangle(box, fill=color, outline='#162536', width=2 * scale)
            draw.text((col * 64 * scale + 8 * scale, row * 64 * scale + 24 * scale), f'{row}:{col}', fill='#152232', font_size=12 * scale)
    save('uv_checker', image)


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    face('smile')
    face('wink', wink=True)
    for name in ['basketball', 'soccer', 'billiard']:
        spherical(name)
    uv_checker()
