# 🎮 Final Round

**Final Round** is a 2D action/fighting game developed using the [Godot Engine](https://godotengine.org/). This project explores decision-based AI behavior, state machines, and modular scene architecture. It was developed as part of an academic project focused on game development and AI integration.

---

## 🚀 Getting Started

### Prerequisites

- [Godot Engine 4.x](https://godotengine.org/download) installed on your system.

### How to Run the Game

1. **Clone this repository:**

   ```bash
   git clone https://github.com/hamzaawad101/finalRound.git
   cd finalRound

2. **Open the Project in Godot:**
* Launch the Godot Editor.
* Click on "Import".
* Navigate to the cloned folder and select project.godot.
* Click "Open", then "Edit" to open the project.

3. **Play the Game:**
* Press F5 or click the ▶ Play Scene button to start the game.
* The default scene (e.g., ground.tscn) can be configured under Project > Project Settings > Application > Run > Main Scene.

## 🎮 Controls
| Action          | Key             |
| --------------- | ----------------|
| Move Left/Right | Left/Right Arrow|
| Jump            | Up Arrow        |
| Attack          | A               |

## 📁 Project Structure
```plaintext
finalRound/
├── .vscode/                 # VSCode settings
├── characters/              # Character scenes and prefabs
│   ├── player.gd            # Player script
│   ├── AI2.gd               # AI character logic
│   ├── character_slot.tscn  # Character selection slot
├── decision_ai/             # Decision tree system
│   ├── TreeNode.gd
│   ├── DecisionNode.gd
│   ├── ActionNode.gd
│   ├── StateGraph.gd
├── scenes/                  # Game scenes
│   ├── intro.tscn           # Intro screen
│   ├── menu.tscn            # Main menu
│   ├── ground.tscn          # Main gameplay scene
├── Sprites copy/            # Game assets (tiles, characters)
│   ├── Tiles.png
│   ├── Pixelated Japanese Landscape Serenity.png
├── project.godot            # Godot project file
