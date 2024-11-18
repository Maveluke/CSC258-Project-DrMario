################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Dr Mario.
#
# Student 1: Janis Joplin, 1009715051
# Student 2: Maverick Luke, 1009714855
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       2
# - Unit height in pixels:      2
# - Display width in pixels:    64
# - Display height in pixels:   64
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

##############################################################################
# Macros
##############################################################################
.macro STORE_TO_STACK(%reg)
    addi $sp, $sp, -4       # decrement stack pointer by 4 bytes (1 word)
    sw %reg, 0($sp)         # store word from register onto stack
.end_macro

.macro RESTORE_FROM_STACK(%reg)
    lw %reg, 0($sp)         # load word from stack into register
    addi $sp, $sp, 4        # increment stack pointer by 4 bytes (1 word)
.end_macro

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000
RED:
    .word 0xff0000
BLUE:
    .word 0x0000ff
YELLOW:
    .word 0xffff00
WHITE:
    .word 0xffffff
BLACK:
    .word 0x000000

##############################################################################
# Mutable Data
##############################################################################
CURR_CAPSULE_STATE:
    .space 16

# s0: Current capsule block's top left pixel address

PREV_BITMAP:
    .space 4096

##############################################################################
# Code
##############################################################################
	.text
	.globl main

# Note: We are using 2x2 pixel blocks to represent the current state of the capsule

    # Run the game.
main:
    # Initialize the game
    jal clear_screen

    jal draw_bottle

    # Set the initial capsule location
    li $a2, 12  # X coordinate
    li $a3, 9   # Y coordinate
    jal calculate_pixel_address
    move $a3, $v0

    jal init_capsule_state
    jal generate_random_capsule_colors
    jal draw_capsule


game_loop:
    # 1a. Check if key has been pressed
    lw $t0, ADDR_KBRD                   # $t0 = base address for keyboard
    lw $t1, 0($t0)                      # Load first word from keyboard
    bne $t1, 1, game_loop               # If the first word is not 1, a key hasn't been pressed
    # 1b. Check which key has been pressed
    lw $t1, 4($t0)                      # $t1 = key pressed (second word from keyboard)
    beq $t1, 0x71, game_end             # Check if the key is 'q'
    beq $t1, 0x77, handle_rotate        # Check if the key is 'w'
    beq $t1, 0x61, handle_move_left     # Check if the key is 'a'
    beq $t1, 0x73, handle_move_down     # Check if the key is 's'
    beq $t1, 0x64, handle_move_right    # Check if the key is 'd'
    j game_loop                         # Invalid key pressed, go back to the game loop
    handle_rotate:
        jal rotate
        j after_handling_move
    handle_move_left:
        jal move_left
        j after_handling_move
    handle_move_down:
        jal move_down
        j after_handling_move
    handle_move_right:
        jal move_right
        j after_handling_move
    
    after_handling_move:
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep
	li $v0, 32
	li $a0, 16
	syscall

    # 5. Go back to Step 1
    j game_loop
game_end:
    li $v0, 10                  # Terminate the program gracefully
    syscall


##############################################################################
# Function to clear the screen
# Clear screen to black
clear_screen:
    lw $t0, ADDR_DSPL    # Load base address
    li $t1, 4096              # 64 * 64 pixels
    lw $t2, BLACK             # Load black color

    clear_loop:
        sw $t2, 0($t0)            # Store black color
        addi $t0, $t0, 4         # Next pixel
        addi $t1, $t1, -1        # Decrement counter
        bnez $t1, clear_loop     # Continue if not done
        jr $ra


##############################################################################
# Function to return the current capsule pattern (1 or 2)
# Note: 1 means the pixel is colored, 0 means the pixel is black
# Pattern 1: 0 0
#            1 1
# Pattern 2: 1 0
#            1 0
# Return value: $v0 = 1 (pattern 1) or $v0 = 2 (pattern 2)
get_pattern:
    lw $t1, 0($s0)                  # $t1 = color of the top left pixel
    beq $t1, 0, pattern_1           # Check if the top left pixel is black
    j pattern_2                     # The top left pixel is colored
    pattern_1:
        li $v0, 1                   # Return pattern 1
        jr $ra
    pattern_2:
        li $v0, 2                   # Return pattern 2
        jr $ra


##############################################################################
# Function to handle capsule movement to the left (pressing a)
# Assumption: The capsule position is valid before moving left
# Note: The capsule can only move left if there is nothing on the left
move_left:
    lw $t9, BLACK                       # $t9 = black
    # Check if the bottom left pixel of the capsule block can move 
    addi $t0, $s0, 128                  # $t0 = address of the bottom left pixel of the capsule block
    addi $t0, $t0, -4                   # $t0 = new address of the bottom left pixel of the capsule block after moving left
    lw $t1, 0($t0)                      # $t1 = color of the new address of the bottom left pixel of the capsule block
    beq $t1, $t9, ml_end                # Check if the new address of the bottom left pixel isn't occupied (is black)
    # The bottom left pixel of the capsule block can move left
    # Check if other pixels of the capsule block can move left
    jal get_pattern                     # Get the pattern of the current capsule block
    beq $v0, 1, ml_can_move             # Check if the pattern is 1
    # The pattern is 2
    addi $t0, $s0, 0                    # $t0 = address of the top left pixel of the capsule block
    addi $t0, $t0, -4                   # $t0 = new address of the top left pixel of the capsule block after moving left
    lw $t1, 0($t0)                      # $t1 = color of the new address of the top left pixel of the capsule block
    beq $t1, $t9, ml_can_move           # Check if the new address of the top left pixel isn't occupied (is black)
    j ml_end                            # The capsule can't move left

    ml_can_move:
        addi $s0, $s0, -4               # Move the capsule block left by 1 pixel
    ml_end:
        # Return to the calling program
        jr $ra


##############################################################################
# Function to handle capsule movement to the right (pressing d)
# Assumption: The capsule position is valid before moving right
# Note: The capsule can only move right if there is nothing on the right
move_right:
    lw $t9, BLACK                       # $t9 = black
    jal get_pattern                     # Get the pattern of the current capsule block
    beq $v0, 1, mr_pattern_1            # Check if the pattern is 1
    j mr_pattern_2                      # The pattern is 2

    mr_pattern_1:
        # Check if the bottom right pixel of the capsule block can move right
        addi $t0, $s0, 132              # $t0 = address of the bottom right pixel of the capsule block
        addi $t0, $t0, 4                # $t0 = new address of the bottom right pixel of the capsule block after moving right
        lw $t1, 0($t0)                  # $t1 = color of the new address of the bottom right pixel of the capsule block
        beq $t1, $t9, mr_can_move       # Check if the new address of the bottom right pixel isn't occupied (is black)
        # The bottom right pixel of the capsule block can't move right
        j mr_end
    mr_pattern_2:
        # Check if the top left pixel of the capsule block can move right
        addi $t0, $s0, 0                # $t0 = address of the top left pixel of the capsule block
        addi $t0, $t0, 4                # $t0 = new address of the top left pixel of the capsule block after moving right
        lw $t1, 0($t0)                  # $t1 = color of the new address of the top left pixel of the capsule block
        bne $t1, $t9, mr_end            # Check if the new address of the top left pixel is occupied (isn't black)
        # The top left pixel of the capsule block can move right
        # Check if the bottom left pixel of the capsule block can move right
        addi $t0, $s0, 128              # $t0 = address of the bottom left pixel of the capsule block
        addi $t0, $t0, 4                # $t0 = new address of the bottom left pixel of the capsule block after moving right
        lw $t1, 0($t0)                  # $t1 = color of the new address of the bottom left pixel of the capsule block
        bne $t1, $t9, mr_end            # Check if the new address of the bottom left pixel is occupied (isn't black)
        j mr_can_move                   # The bottom left pixel of the capsule block also can move right
    mr_can_move:
        addi $s0, $s0, 4                # Move the capsule block right by 1 pixel
    mr_end:
        # Return to the calling program
        jr $ra


##############################################################################
# Function to handle capsule movement down (pressing s)
# Assumption: The capsule position is valid before moving down
# Note: The capsule can only move down if there is nothing below it
move_down:
    lw $t9, BLACK                       # $t9 = black
    # Check if the bottom left pixel of the capsule block can move down
    addi $t0, $s0, 128                  # $t0 = address of the bottom left pixel of the capsule block
    addi $t0, $t0, 128                  # $t0 = new address of the bottom left pixel of the capsule block after moving down
    lw $t1, 0($t0)                      # $t1 = color of the new address of the bottom left pixel of the capsule block
    bne $t1, $t9, md_end                # Check if the new address of the bottom left pixel is occupied (isn't black)
    # The bottom left pixel of the capsule block can move down
    # Check if other pixels of the capsule block can move down
    jal get_pattern                     # Get the pattern of the current capsule block
    beq $v0, 2, md_can_move             # Check if the pattern is 2
    # The pattern is 1
    # Check if the bottom right pixel of the capsule block can move down
    addi $t0, $s0, 132                  # $t0 = address of the bottom right pixel of the capsule block
    addi $t0, $t0, 128                  # $t0 = new address of the bottom right pixel of the capsule block after moving down
    lw $t1, 0($t0)                      # $t1 = color of the new address of the bottom right pixel of the capsule block
    bne $t1, $t9, md_end                # Check if the new address of the bottom right pixel is occupied (isn't black)
    j md_can_move                       # The bottom right pixel of the capsule block also can move down

    md_can_move:
        addi $s0, $s0, 128              # Move the capsule block down by 1 pixel
    md_end:
        # Return to the calling program
        jr $ra


##############################################################################
# Function to rotate the capsule block clockwise (pressing w)
# Assumption: The capsule position is valid before rotating
# Note: The capsule can only rotate if it doesn't collide with other blocks
rotate:
    lw $t9, BLACK                       # $t9 = black
    jal get_pattern                     # Get the pattern of the current capsule block
    beq $v0, 1, r_pattern_1             # Check if the pattern is 1
    j r_pattern_2                       # The pattern is 2

    r_pattern_1:
        # Check if the top left pixel of the capsule block is empty (black)
        addi $t0, $s0, 0                # $t0 = address of the top left pixel of the capsule block
        lw $t1, 0($t0)                  # $t1 = color of the top left pixel of the capsule block
        beq $t1, $t9, r_can_rotate_1    # Check if the top left pixel is black
        j r_end                         # The capsule block can't rotate
    r_pattern_2:
        # Check if the bottom right pixel of the capsule block is empty (black)
        addi $t0, $s0, 132              # $t0 = address of the bottom right pixel of the capsule block
        lw $t1, 0($t0)                  # $t1 = color of the bottom right pixel of the capsule block
        beq $t1, $t9, r_can_rotate_2    # Check if the bottom right pixel is black
        j r_end                         # The capsule block can't rotate
    r_can_rotate_1:
        # Rotate the capsule block from pattern 1 to pattern 2
        addi $t0, $s0, 0                # $t0 = address of the top left pixel of the capsule block
        addi $t1, $s0, 128              # $t1 = address of the bottom left pixel of the capsule block
        lw $t2, 0($t1)                  # $t2 = color of the bottom left pixel of the capsule block
        addi $t3, $s0, 132              # $t2 = address of the bottom right pixel of the capsule block
        lw $t4, 0($t3)                  # $t4 = color of the bottom right pixel of the capsule block
        sw $t2, 0($t0)                  # Move the color of the bottom left pixel to the top left pixel
        sw $t4, 0($t1)                  # Move the color of the bottom right pixel to the bottom left pixel
        j r_end
    r_can_rotate_2:
        # Rotate the capsule block from pattern 2 to pattern 1
        addi $t0, $s0, 0                # $t0 = address of the top left pixel of the capsule block
        lw $t1, 0($t0)                  # $t1 = color of the top left pixel of the capsule block
        addi $t2, $s0, 128              # $t2 = address of the bottom left pixel of the capsule block
        lw $t3, 0($t2)                  # $t3 = color of the bottom left pixel of the capsule block
        addi $t4, $s0, 132              # $t4 = address of the bottom right pixel of the capsule block
        sw $t1, 0($t2)                  # Move the color of the top left pixel to the bottom left pixel
        sw $t3, 0($t4)                  # Move the color of the bottom left pixel to the bottom right pixel
        j r_end
    r_end:
        # Return to the calling program
        jr $ra


##############################################################################
# Function to draw a vertical line on the display
# Assumption: the line can be drawn within the same column
# $a0 = X coordinate of the starting point
# $a1 = Y coordinate of the starting point
# $a2 = length of the line
# $a3 = color of the line
draw_vertical_line:
    # Calculate the address of the starting point
    lw $t0, ADDR_DSPL                   # $t0 = base address for display
    sll $a0, $a0, 2                     # Calculate the X offset to add to $t0 (multiply $a0 by 4)
    sll $a1, $a1, 7                     # Calculate the Y offset to add to $t0 (multiply $a1 by 128)
    add $t0, $t0, $a0                   # Add the X offset to $t0
    add $t0, $t0, $a1                   # Add the Y offset to $t0
    # $t0 now contains the address of the starting point
    # Calculate the address of the ending point
    sll $a2, $a2, 7                     # Multiply the length by 128 to get the number of bytes to move
    add $t1, $t0, $a2                   # Add the length to the starting point to get the ending point
    # $t1 now contains the address of the ending point
    # Draw a vertical line from $t0 to $t1
    dvl_line_start:
        sw $a3, 0($t0)                  # Draw a pixel at the current address with color $a3
        addi $t0, $t0, 128              # Move to the next pixel
        bne $t0, $t1, dvl_line_start    # Repeat until the ending point is reached
    # Return to the calling program
    jr $ra



##############################################################################
# Function to draw a horizontal line on the display
# Assumption: the line can be drawn within the same row
# $a0 = X coordinate of the starting point
# $a1 = Y coordinate of the starting point
# $a2 = length of the line
# $a3 = color of the line
draw_horizontal_line:
    # Calculate the address of the starting point
    lw $t0, ADDR_DSPL                   # $t0 = base address for display
    sll $a0, $a0, 2                     # Calculate the X offset to add to $t0 (multiply $a0 by 4)
    sll $a1, $a1, 7                     # Calculate the Y offset to add to $t0 (multiply $a1 by 128)
    add $t0, $t0, $a0                   # Add the X offset to $t0
    add $t0, $t0, $a1                   # Add the Y offset to $t0
    # $t0 now contains the address of the starting point
    # Calculate the address of the ending point
    sll $a2, $a2, 2                     # Multiply the length by 4 to get the number of bytes to move
    add $t1, $t0, $a2                   # Add the length to the starting point to get the ending point
    # $t1 now contains the address of the ending point
    # Draw a horizontal line from $t0 to $t1
    dhl_line_start:
        sw $a3, 0($t0)                  # Draw a pixel at the current address with color $a3
        addi $t0, $t0, 4                # Move to the next pixel
        bne $t0, $t1, dhl_line_start    # Repeat until the ending point is reached
    # Return to the calling program
    jr $ra


draw_bottle:
    # Save the return address $ra
    STORE_TO_STACK($ra)
    
    # Draw the bottle
    lw $t0, ADDR_DSPL       # $t0 = base address for display
    # Draw the top of the bottle
    li $a0, 6               # $a3 = Starting X coordinate
    li $a1, 9               # $a2 = Starting Y coordinate
    li $a2, 4               # $a2 = Length of the line
    lw $a3, WHITE           # $a3 = Colour
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    STORE_TO_STACK($a3)
    jal draw_vertical_line
    RESTORE_FROM_STACK($a3)
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    li $a0, 10              # $a3 = Starting X coordinate
    li $a1, 9               # $a2 = Starting Y coordinate
    li $a2, 4               # $a2 = Length of the line
    lw $a3, WHITE           # $a3 = Colour
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    STORE_TO_STACK($a3)
    jal draw_vertical_line
    RESTORE_FROM_STACK($a3)
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    li $a0, 2               # $a3 = Starting X coordinate
    li $a1, 12               # $a2 = Starting Y coordinate
    li $a2, 5               # $a2 = Length of the line
    lw $a3, WHITE           # $a3 = Colour
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    STORE_TO_STACK($a3)
    jal draw_horizontal_line
    RESTORE_FROM_STACK($a3)
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    li $a0, 10               # $a3 = Starting X coordinate
    li $a1, 12               # $a2 = Starting Y coordinate
    li $a2, 5               # $a2 = Length of the line
    lw $a3, WHITE           # $a3 = Colour
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    STORE_TO_STACK($a3)
    jal draw_horizontal_line
    RESTORE_FROM_STACK($a3)
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    # Draw the bottom of the bottle
    li $a0, 2              # $a3 = Starting X coordinate
    li $a1, 12               # $a2 = Starting Y coordinate
    li $a2, 18               # $a2 = Length of the line
    lw $a3, WHITE           # $a3 = Colour
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    STORE_TO_STACK($a3)
    jal draw_vertical_line
    RESTORE_FROM_STACK($a3)
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    li $a0, 14              # $a3 = Starting X coordinate
    li $a1, 12               # $a2 = Starting Y coordinate
    li $a2, 18               # $a2 = Length of the line
    lw $a3, WHITE           # $a3 = Colour
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    STORE_TO_STACK($a3)
    jal draw_vertical_line
    RESTORE_FROM_STACK($a3)
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    li $a0, 2               # $a3 = Starting X coordinate
    li $a1, 29               # $a2 = Starting Y coordinate
    li $a2, 13               # $a2 = Length of the line
    lw $a3, WHITE           # $a3 = Colour
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    STORE_TO_STACK($a3)
    jal draw_horizontal_line
    RESTORE_FROM_STACK($a3)
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    RESTORE_FROM_STACK($ra)
    jr $ra


##############################################################################
# Function to calculate pixel address
# Parameters:
# $a2 - x coordinate
# $a3 - y coordinate
# Returns:
# $v0 - pixel address
calculate_pixel_address:
    # Save return address
    STORE_TO_STACK($ra)

    li $t1, 0         # Set $t1 to 0
    # Calculate offset: y * 128 + x * 4
    sll $a2, $a2, 2   # x * 4
    sll $a3, $a3, 7   # y * 128
    add $t1, $t1, $a2 # Add x offset
    add $t1, $t1, $a3 # Add y offset

    # Calculate final address
    lw $v0, ADDR_DSPL
    add $v0, $v0, $t1

    # Restore return address
    RESTORE_FROM_STACK($ra)
    jr $ra

##############################################################################
# Function to initialize the capsule state
# Parameters: 
# $a3 = Address of the top left of the capsule 2x2 box
init_capsule_state:
    move $s0, $a3                  # Store the initial address to $s0
    la $t0, CURR_CAPSULE_STATE      # Load base address

    # Initialize all positions with colors
    lw $t1, BLACK              # Default color (or any other default)
    sw $t1, 0($t0)      # Store in top position
    sw $t1, 4($t0)   # Store in bottom position
    sw $t1, 8($t0)     # Store in left position
    sw $t1, 12($t0)    # Store in right position

    jr $ra

##############################################################################
# Function to set color at specific position
# Parameters:
# $a0 - position offset (0, 4, 8, or 12)
# $a1 - color to set
set_capsule_color:
    la $t0, CURR_CAPSULE_STATE
    add $t0, $t0, $a0         # Add offset to base address
    sw $a1, 0($t0)             # Store color at position
    jr $ra

##############################################################################
# Function to get color at specific position
# Parameters:
# $a0 - position offset (0, 4, 8, or 12)
# Returns:
# $v0 - color at position
get_capsule_color:
    la $t0, CURR_CAPSULE_STATE
    add $t0, $t0, $a0         # Add offset to base address
    lw $v0, 0($t0)             # Load color from position
    jr $ra

##############################################################################
# Function to randomly set two opposite colors
# Returns:
# $t2 - left color
generate_random_capsule_colors:
    # Save return address
    STORE_TO_STACK($ra)

    # Generate first random color
    jal generate_random_color
    move $t2, $v0             # Save first color

    # Generate second random color
    jal generate_random_color
    move $t3, $v0             # Save second color

    # Set left color
    li $a0, 0
    move $a1, $t2
    jal set_capsule_color

    # Set right color
    li $a0, 8
    move $a1, $t3
    jal set_capsule_color

    # Restore return address
    RESTORE_FROM_STACK($ra)
    jr $ra

##############################################################################
# Function to draw a capsule on the display
# The location of the capsule is stored in $s0
# The color of the 2x2 box for the capsule is stored in CURR_CAPSULE_STATE
draw_capsule:
    move $t0, $s0            # Set the starting address for the capsule stored in $s0
    la $t1, CURR_CAPSULE_STATE      # Set the current color palette
    lw $t2, 0($t1)                  # Set the top left color
    lw $t3, 4($t1)                  # Set the top right color
    lw $t4, 8($t1)                  # Set the bottom left color
    lw $t5, 12($t1)                 # Set the bottow right color

    # Start drawing
    sw $t2, 0($t0)
    sw $t3, 4($t0)
    sw $t4, 128($t0)
    sw $t5, 132($t0)
    
    jr $ra

##############################################################################
# Function to return random color
# Return values:
# - $v0: The color generated
generate_random_color:
    # Generate a random number from 0 - 2 inclusive, and put the result in $a0 register
    li $v0, 42              # syscall 42: generate random number
    li $a0, 0               # Random number generated from 0
    li $a1, 3               # to 2 inclusive
    syscall

    beq $a0, 0, return_red
    beq $a0, 1, return_blue
    beq $a0, 2, return_yellow
    lw $v0, WHITE

    j grc_end

    return_red:
        lw $v0, RED
        j grc_end

    return_blue:
        lw $v0, BLUE
        j grc_end

    return_yellow:
        lw $v0, YELLOW
        j grc_end

    grc_end:
        jr $ra