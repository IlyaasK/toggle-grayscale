#!/bin/bash

# Check if the required dependencies are installed
dependencies=("hyprctl")
missing_deps=()

for dep in "${dependencies[@]}"; do
  if ! command -v "$dep" &> /dev/null; then
    missing_deps+=("$dep")
  fi
done

if [ ${#missing_deps[@]} -ne 0 ]; then
  echo "Missing dependencies: ${missing_deps[*]}"
  echo "Install them using: sudo pacman -S ${missing_deps[*]}"
  exit 1
fi

# Setup directories
SHADER_DIR="$HOME/.config/hypr/shaders"
GRAYSCALE_SHADER="$SHADER_DIR/grayscale.frag"
BLUELIGHT_SHADER="$SHADER_DIR/bluelight.frag"
COMBINED_SHADER="$SHADER_DIR/grayscale_bluelight.frag"
STATE_FILE="$SHADER_DIR/.shader_state"

# Create shader directory if it doesn't exist
if [ ! -d "$SHADER_DIR" ]; then
  mkdir -p "$SHADER_DIR"
fi

# Create state file if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
  echo "normal" > "$STATE_FILE"
fi

# Create grayscale shader if it doesn't exist
if [ ! -f "$GRAYSCALE_SHADER" ]; then
  cat > "$GRAYSCALE_SHADER" << 'EOF'
precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

void main() {
    vec4 color = texture2D(tex, v_texcoord);
    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    gl_FragColor = vec4(vec3(gray), color.a);
}
EOF
fi

# Create blue light filter shader with deep orange tones
if [ -f "$BLUELIGHT_SHADER" ]; then
  rm "$BLUELIGHT_SHADER"
fi

cat > "$BLUELIGHT_SHADER" << 'EOF'
precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

void main() {
    vec4 color = texture2D(tex, v_texcoord);
    
    // Almost eliminate blue light
    color.b = color.b * 0.25;
    
    // Boost red significantly for deep orange/amber
    color.r = min(1.0, color.r * 1.3);
    
    // Reduce green slightly to shift from yellow to orange
    color.g = color.g * 0.85;
    
    gl_FragColor = color;
}
EOF

# Create combined shader with deep orange tones
if [ -f "$COMBINED_SHADER" ]; then
  rm "$COMBINED_SHADER"
fi

cat > "$COMBINED_SHADER" << 'EOF'
precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

void main() {
    vec4 color = texture2D(tex, v_texcoord);
    
    // First grayscale
    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    vec4 grayColor = vec4(vec3(gray), color.a);
    
    // Then apply deep orange filter
    grayColor.b = grayColor.b * 0.2;  // Almost eliminate blue
    grayColor.r = min(1.0, grayColor.r * 1.35);  // Heavy red emphasis
    grayColor.g = grayColor.g * 0.8;  // Reduced green to shift from yellow to orange
    
    gl_FragColor = grayColor;
}
EOF

# Function to cycle through shader modes
cycle_shaders() {
  current_state=$(cat "$STATE_FILE")
  
  case "$current_state" in
    "normal")
      hyprctl keyword decoration:screen_shader "$GRAYSCALE_SHADER"
      echo "grayscale" > "$STATE_FILE"
      echo "Grayscale mode enabled"
      ;;
    "grayscale")
      hyprctl keyword decoration:screen_shader "$BLUELIGHT_SHADER"
      echo "bluelight" > "$STATE_FILE"
      echo "Deep orange night filter enabled"
      ;;
    "bluelight")
      hyprctl keyword decoration:screen_shader "$COMBINED_SHADER"
      echo "combined" > "$STATE_FILE"
      echo "Combined grayscale + deep orange night filter enabled"
      ;;
    "combined")
      hyprctl keyword decoration:screen_shader ""
      echo "normal" > "$STATE_FILE"
      echo "All filters disabled"
      ;;
    *)
      hyprctl keyword decoration:screen_shader ""
      echo "normal" > "$STATE_FILE"
      echo "Reset to normal mode"
      ;;
  esac
}

# Direct mode selection if argument provided
if [ "$1" == "gray" ] || [ "$1" == "grayscale" ]; then
  hyprctl keyword decoration:screen_shader "$GRAYSCALE_SHADER"
  echo "grayscale" > "$STATE_FILE"
  echo "Grayscale mode enabled"
  exit 0
elif [ "$1" == "blue" ] || [ "$1" == "bluelight" ]; then
  hyprctl keyword decoration:screen_shader "$BLUELIGHT_SHADER"
  echo "bluelight" > "$STATE_FILE"
  echo "Deep orange night filter enabled"
  exit 0
elif [ "$1" == "both" ] || [ "$1" == "combined" ]; then
  hyprctl keyword decoration:screen_shader "$COMBINED_SHADER"
  echo "combined" > "$STATE_FILE"
  echo "Combined grayscale + deep orange night filter enabled"
  exit 0
elif [ "$1" == "off" ] || [ "$1" == "normal" ]; then
  hyprctl keyword decoration:screen_shader ""
  echo "normal" > "$STATE_FILE"
  echo "All filters disabled"
  exit 0
fi

# Main execution (cycle through modes)
cycle_shaders

exit 0
