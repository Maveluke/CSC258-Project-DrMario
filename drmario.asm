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

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize the game

game_loop:
    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep

    # 5. Go back to Step 1
    j game_loop

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