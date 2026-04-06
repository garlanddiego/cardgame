#!/usr/bin/env python3
"""Generate bloodfiend fallen/death sprite using Gemini API."""

import json, urllib.request, base64, os, sys, time
from PIL import Image
import numpy as np

# Load Gemini config
with open(os.path.expanduser('~/.genimg/config.json')) as f:
    config = json.load(f)
gemini = config['providers']['gemini']
API_KEY = gemini['api_key']
MODEL = gemini.get('model', 'gemini-2.5-flash-image')

print(f'Using model: {MODEL}')

BLOODFIEND_DESC = (
    'a dark vampire blood warrior demon in crimson red spiked plate armor, '
    'large curved demon horns on helmet, tattered red cape flowing, '
    'clawed gauntlets dripping blood, glowing red eyes'
)

PROMPT = (
    'Generate a 512x512 pixel game sprite on a solid bright green (#00FF00) background. '
    f'{BLOODFIEND_DESC}, collapsed and fallen on the ground in a defeated death pose, '
    'lying sideways with armor cracked and damaged, one arm reaching forward weakly, '
    'cape spread on ground, completely defeated and exhausted. '
    'The character should fill about 70-80% of the canvas width since the fallen horizontal pose '
    'takes more horizontal space. Character positioned in lower-center of frame. '
    '2D cartoon game art style, bold black outlines, cel-shading, flat colors, dark fantasy, '
    'similar to Slay the Spire card game art style. '
    'No text, no labels, no UI elements. '
    'Solid bright green (#00FF00) background only, no ground texture, no shadows on background.'
)

url = f'https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={API_KEY}'
payload = {
    'contents': [{'parts': [{'text': PROMPT}]}],
    'generationConfig': {'responseModalities': ['TEXT', 'IMAGE']}
}

output_path = 'assets/img/bloodfiend_fallen.png'
tmp_dir = os.environ.get('TMPDIR', '/tmp')
tmp_path = os.path.join(tmp_dir, 'bloodfiend_fallen_raw.png')

for attempt in range(3):
    try:
        print(f'Attempt {attempt+1}...')
        req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                    headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=180) as resp:
            data = json.load(resp)

        found_image = False
        for candidate in data.get('candidates', []):
            for part in candidate.get('content', {}).get('parts', []):
                if 'inlineData' in part:
                    img_data = base64.b64decode(part['inlineData']['data'])
                    with open(tmp_path, 'wb') as f:
                        f.write(img_data)

                    # Open and process
                    img = Image.open(tmp_path).convert('RGBA')
                    print(f'Raw image size: {img.size}')

                    # Resize to 512x512 if needed
                    if img.size != (512, 512):
                        img = img.resize((512, 512), Image.LANCZOS)

                    # Remove green background
                    arr = np.array(img).astype(np.int32)
                    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]

                    # Detect green background pixels
                    green_mask = (g > 150) & (r < 150) & (b < 150) & (g > r + 30) & (g > b + 30)
                    light_green_mask = (g > 180) & (r < 180) & (b < 180) & (g > r + 20) & (g > b + 20)
                    full_mask = green_mask | light_green_mask

                    # Set alpha to 0 for green pixels
                    result_arr = np.array(img).copy()
                    result_arr[full_mask, 3] = 0

                    # Clean up green fringing on edge pixels using scipy
                    try:
                        from scipy import ndimage
                        dilated = ndimage.binary_dilation(full_mask, iterations=1)
                        edge_pixels = dilated & ~full_mask

                        # For edge pixels, reduce green channel
                        edge_y, edge_x = np.where(edge_pixels)
                        for y, x in zip(edge_y, edge_x):
                            rr = int(result_arr[y, x, 0])
                            gg = int(result_arr[y, x, 1])
                            bb = int(result_arr[y, x, 2])
                            if gg > rr and gg > bb:
                                avg = (rr + bb) // 2
                                result_arr[y, x, 1] = min(gg, avg + 10)
                    except ImportError:
                        print('scipy not available, skipping edge cleanup')

                    result = Image.fromarray(result_arr)
                    result.save(output_path)
                    print(f'Saved {output_path} ({os.path.getsize(output_path)} bytes)')
                    print(f'Size: {result.size}, Mode: {result.mode}')
                    found_image = True
                    break
                elif 'text' in part:
                    print(f'Text: {part["text"][:200]}')
            if found_image:
                break

        if found_image:
            print('Done!')
            sys.exit(0)

        print('No image in response, retrying...')
        time.sleep(3)
    except Exception as e:
        print(f'Error: {e}')
        import traceback
        traceback.print_exc()
        if attempt < 2:
            time.sleep(5)

print('Failed after all attempts')
sys.exit(1)
