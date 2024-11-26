# Dr. Mario MIPS Assembly Implementation

## Overview
This project is a MIPS assembly implementation of the classic Nintendo game Dr. Mario, developed using the Saturn MIPS simulator. Players must strategically position and rotate colored capsules to eliminate viruses by matching four or more colors in a row, either horizontally or vertically. This project is part of the CSC258 final project and is inspired by the game _Dr. Mario_. An online version of the game can be accessed [here](https://www.retrogames.onl/2017/05/dr-mario-nes.html).

## Features
- Complete implementation of core Dr. Mario gameplay mechanics
- Real-time capsule movement and rotation
- Collision detection and gravity simulation
- Virus elimination system
- Sound effects for various game events
- Pause functionality

## Controls
- **W**: Rotate capsule
- **A**: Move left
- **S**: Move down
- **D**: Move right
- **P**: Pause game
- **R**: Reset game
- **Q**: Quit game

## Technical Details
### Display Configuration
- Unit width in pixels: 2
- Unit height in pixels: 2
- Display width in pixels: 64
- Display height in pixels: 64
- Base Address for Display: 0x10008000

### Game Components
- **Bottle System**: Implements game boundaries and collision detection
- **Capsule Management**: Handles capsule generation, movement, and rotation
- **Virus System**: Manages virus placement and elimination
- **Color Matching**: Detects and removes matching color sequences
- **Physics**: Simulates falling capsules and chain reactions
- **Sound System**: Provides audio feedback for game events

## How to Run
1. Download [Saturn](https://github.com/1whatleytay/saturn/releases)
2. Open `drmario.asm` in Saturn
3. Connect the bitmap display with the following settings:
   - Unit Width: 2
   - Unit Height: 2
   - Display Width: 64
   - Display Height: 64
   - Base Address: 0x10008000
4. Run the program
5. Enjoy the game!

## Implementation Details
The game is implemented using several key components:
- Memory management for game state
- Efficient bitmap display manipulation
- Keyboard input handling
- Collision detection algorithms
- Color matching and elimination logic
- Sound effect generation
- Game loop with frame timing

## Technical Challenges
- Implementing smooth capsule movement and rotation in assembly
- Managing complex game state with limited registers
- Optimizing collision detection and color matching algorithms
- Handling multiple simultaneous events and animations
- Implementing chain reactions for falling capsules

## Contributors
- Janis Joplin (1009715051)
- Maverick Luke (1009714855)

## Academic Context
This project was developed as part of CSC258H1: Computer Organization at the University of Toronto. The course focuses on fundamental computer structures, machine languages, instruction execution, addressing techniques, and digital representation of data.

This Dr. Mario implementation serves as a practical demonstration of core course concepts:
- Machine Language Programming: Direct use of MIPS assembly for all game functionality
- Memory management
- Bitmap manipulation
- Input handling
- Game loop implementation
- Sound generation

## License
This project is for educational purposes only. Dr. Mario is a trademark of Nintendo.
