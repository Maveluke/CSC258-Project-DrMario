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
GRID_WIDTH:
    .word 11
GRID_HEIGHT:
    .word 16
RED:
    .word 0xff0000    # Bright red
GREEN:
    .word 0x00ff00    # Bright green
BLUE:
    .word 0x0000ff    # Bright blue
WHITE:
    .word 0xffffff
BLACK:
    .word 0x000000
ADDR_NEXT_CAPSULE:
    .word 0x100084b0
ADDR_START_CAPSULE:
    .word 0x100086a0
BOTTLE_TL_X:
    .word 3
BOTTLE_TL_Y:
    .word 13
ADDR_VIRUS_STARTING_POINT:
    .word 0x1000888c  # 17 * (32 * 4) + 3 * 4 = 2188
POSSIBLE_VIRUS_POSITION_HEIGHT:
    .word 12          # 3 / 4 * GRID_HEIGHT = 12
POSSIBLE_VIRUS_POSITION_WIDTH:
    .word 11          # GRID_WIDTH = 11
# Virus colors - darker variants of the regular colors
RED_VIRUS:
    .word 0x990000    # Dark red
GREEN_VIRUS:
    .word 0x009900    # Dark green
BLUE_VIRUS:
    .word 0x000099    # Dark blue
ADDR_GRID_START:
    .word 0x1000868c  # 13 * (32 * 4) + 3 * 4 => 1676 + 0x10008000
OFFSET_FROM_TOP_LEFT:
    .word 1676

##############################################################################
# Mutable Data
##############################################################################
NEXT_CAPSULE_STATE:
    .space 16

CURR_CAPSULE_STATE:
    .space 16

# s0: Current capsule block's top left pixel address in the bitmap
# s1: The current number of viruses in the bottle

PREV_BITMAP:
    .space 4096

# Matrix storing capsule connections: For each cell containing half a capsule (part of a full capsule),  
# stores the offset of its other half, relative to the base. Uses 0 for cells that aren't part of a capsule
ALLOC_OFFSET_CAPSULE_HALF:
    .space 4096

# Integer storing the number of viruses in the bottle
VIRUS_COUNT:
    .word 4
##############################################################################
# Code
##############################################################################
	.text
	.globl main

# Note: We are using 2x2 pixel blocks to represent the current state of the capsule

    # Run the game.
main:
    # Reset all ALLOC_OFFSET_CAPSULE_HALF values to 0
    la $t0, ALLOC_OFFSET_CAPSULE_HALF       # Load array address
    li $t1, 1024                            # Number of words (4096/4)
    clear:
        sw $zero, 0($t0)                    # Store 0
        addi $t0, $t0, 4                    # Next word
        addi $t1, $t1, -1                   # Decrement counter
        bnez $t1, clear                     # Continue if counter not zero

    # Initialize the game
    jal clear_screen
    jal draw_bottle

    # Initialize the viruses
    lw $s1, VIRUS_COUNT         # $s1 = initial number of viruses
    jal draw_viruses            # Draw the viruses

    # Initialize the next capsule state
    lw $a3, ADDR_NEXT_CAPSULE
    # Draw the initial capsule
    jal init_capsule_state
    jal generate_random_capsule_colors
    jal draw_next_capsule


game_loop:
    # Draw new capsule from the next capsule
    # Initialize the new capsule
    jal set_new_capsule
    jal draw_capsule

    # Check if the new capsule can move down
    beq $v0, 1, game_end

    # Generate the next capsule state
    jal init_capsule_state
    jal generate_random_capsule_colors
    jal draw_next_capsule

    gl_after_generate:
    # 1a. Check if key has been pressed
    lw $t0, ADDR_KBRD                   # $t0 = base address for keyboard
    lw $t1, 0($t0)                      # Load first word from keyboard
    bne $t1, 1, gl_after_generate       # If the first word is not 1, no key is pressed
    # 1b. Check which key has been pressed
    lw $t1, 4($t0)                      # $t1 = key pressed (second word from keyboard)
    beq $t1, 0x70, handle_pause         # Check if the key is 'p'
    beq $t1, 0x71, game_end             # Check if the key is 'q'
    beq $t1, 0x77, handle_rotate        # Check if the key is 'w'
    beq $t1, 0x61, handle_move_left     # Check if the key is 'a'
    beq $t1, 0x73, handle_move_down     # Check if the key is 's'
    beq $t1, 0x64, handle_move_right    # Check if the key is 'd'
    beq $t1, 0x72, handle_reset         # Check if the key is 'r'
    beq $t1, 0x7a, debug_change_capsule # Check if the key is 'z' TODO: delete this for production
    j gl_after_generate                 # Invalid key pressed, get another key
    handle_rotate:
        jal rotate
        j after_handling_move
    handle_move_left:
        jal move_left
        j after_handling_move
    handle_move_down:
        jal move_down
        beq $v0, 1, handle_remove_consecutives  # If the capsule can't move down, check for any consecutive color pixels
        j after_handling_move
    handle_move_right:
        jal move_right
        j after_handling_move
    debug_change_capsule:
        jal remove_capsule
        j generate_new_capsule
    handle_reset:
        j main

    handle_relationship_matrix:
        jal initialize_capsule_to_matrix
    handle_remove_consecutives:
        jal scan_consecutives
        beq $v0, 1, handle_falling
        j generate_new_capsule
    handle_falling:
        jal scan_falling_capsules
        beq $v1, 1, handle_remove_consecutives
        j generate_new_capsule
    after_handling_move:
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep
	li $v0, 32
	li $a0, 16
	syscall

    j gl_after_generate
    # 5. Go back to Step 1



    generate_new_capsule:
        # If there's no more viruses, end the game
        beq $s1, $zero, game_end
        # There's at least one virus left, generate a new capsule
        j game_loop
game_end:
    li $v0, 10                  # Terminate the program gracefully
    syscall


##############################################################################
# Function to clear the screen
# Clear screen to black
# Registers changed: $t0, $t1, $t2
clear_screen:
    lw $t0, ADDR_DSPL           # Load base address
    li $t1, 4096                # 64 * 64 pixels
    lw $t2, BLACK               # Load black color

    clear_loop:
        sw $t2, 0($t0)          # Store black color
        addi $t0, $t0, 4        # Next pixel
        addi $t1, $t1, -1       # Decrement counter
        bnez $t1, clear_loop    # Continue if not done
        jr $ra


initialize_capsule_to_matrix:
    la $t0, ALLOC_OFFSET_CAPSULE_HALF           # $t0 = address of ALLOC_OFFSET_CAPSULE_HALF
    lw $t1, ADDR_DSPL                           # $t1 = base address for display
    sub $t2, $s0, $t1                           # $t2 = offset of the top left pixel of the capsule block

##############################################################################
# Helper function to check if colors match (including virus variants)
# Parameters: $a0 = first color, $a1 = second color
# Registers changed: $v0, $a0, $a1, $t0, $t1, $t2, $t3, $t4, $t5
# Returns: $v0 = 1 if colors match, 0 otherwise
check_matching_colors:
    STORE_TO_STACK($ra)

    # Load virus colors
    lw $t0, RED_VIRUS
    lw $t1, RED
    lw $t2, GREEN_VIRUS
    lw $t3, GREEN
    lw $t4, BLUE_VIRUS
    lw $t5, BLUE

    # Check red variants
    beq $a0, $t0, check_red          # First color is red virus
    beq $a0, $t1, check_red          # First color is red capsule

    # Check green variants
    beq $a0, $t2, check_green        # First color is green virus
    beq $a0, $t3, check_green        # First color is green capsule

    # Check blue variants
    beq $a0, $t4, check_blue         # First color is blue virus
    beq $a0, $t5, check_blue         # First color is blue capsule

    # No match found
    li $v0, 0
    j check_end

    check_red:
        beq $a1, $t0, colors_match      # Second color is red virus
        beq $a1, $t1, colors_match      # Second color is red capsule
        li $v0, 0
        j check_end

    check_green:
        beq $a1, $t2, colors_match      # Second color is green virus
        beq $a1, $t3, colors_match      # Second color is green capsule
        li $v0, 0
        j check_end

    check_blue:
        beq $a1, $t4, colors_match      # Second color is blue virus
        beq $a1, $t5, colors_match      # Second color is blue capsule
        li $v0, 0
        j check_end

    colors_match:
        li $v0, 1

    check_end:
        RESTORE_FROM_STACK($ra)
        jr $ra


##############################################################################
# Function to scan for consecutive lines with the same color
# Assumption: The lines to be removed are consecutive
# Registers used: t0, t1, t2, t3, t4, t7, t8, s7
# Returns: $v0 = 1 if there are consecutive lines to be removed, $v0 = 0 otherwise
scan_consecutives:
    li $v0, 0                       # Initialize return value to 0
    STORE_TO_STACK($ra)

    li $t1, 0                       # t1 = row to be scanned
    lw $t7, GRID_HEIGHT             # t7 = grid's height
    lw $t8, GRID_WIDTH              # t8 = grid's width

    # Scan horizontally (t1, t2)
    sc_while_h: beq $t1, $t7, sc_end_h                  # Check if the row has reached the end
        li $t2, 0                                       # t2 = current column
        # t0 = the address to the current pixel (ADDR_GRID_START(3, 13) + t1 * 128 (t1 move vertically))
        sll $t0, $t1, 7
        lw $s7, ADDR_GRID_START
        add $t0, $t0, $s7

        lw $t3, 0($t0)                                  # t3 = current pixel color
        li $t4, 0                                       # t4 = counter for number of consecutives with same colors
        sc_while_hc: beq $t2, $t8, sc_end_hc        # Check if end of row
            sll $s7, $t2, 2                         # Calculate offset
            add $t5, $t0, $s7                       # Get current pixel address

            lw $s7, 0($t5)                          # Load current color
            beq $s7, $zero, sc_reset_count_hc          # If black, reset count

            # Check if colors match (including virus variants)
            STORE_TO_STACK($t0)
            STORE_TO_STACK($t1)
            STORE_TO_STACK($t2)
            STORE_TO_STACK($t3)
            STORE_TO_STACK($t4)
            STORE_TO_STACK($t5)
            move $a0, $t3                           # First color (tracked)
            move $a1, $s7                           # Second color (current)
            jal check_matching_colors
            RESTORE_FROM_STACK($t5)
            RESTORE_FROM_STACK($t4)
            RESTORE_FROM_STACK($t3)
            RESTORE_FROM_STACK($t2)
            RESTORE_FROM_STACK($t1)
            RESTORE_FROM_STACK($t0)

            beq $v0, 1, sc_increment_hc            # If colors match, increment
            # Different color (not black)
            move $t3, $s7                           # Track new color
            li $t4, 1                               # Reset count to 1
            j sc_cont_while_hc

            sc_increment_hc:
            beq $t3, $zero, sc_cont_while_hc        # Skip if tracking black
            addi $t4, $t4, 1                        # Increment count
            lw $s7, 4($t5)                          # Load next color
            # Check if colors match (including virus variants)
            STORE_TO_STACK($t0)
            STORE_TO_STACK($t1)
            STORE_TO_STACK($t2)
            STORE_TO_STACK($t3)
            STORE_TO_STACK($t4)
            STORE_TO_STACK($t5)
            move $a0, $t3                           # First color (tracked)
            move $a1, $s7                           # Second color (current)
            jal check_matching_colors
            RESTORE_FROM_STACK($t5)
            RESTORE_FROM_STACK($t4)
            RESTORE_FROM_STACK($t3)
            RESTORE_FROM_STACK($t2)
            RESTORE_FROM_STACK($t1)
            RESTORE_FROM_STACK($t0)

            beq $v0, 1, sc_cont_while_hc            # If colors match, increment
            bge $t4, 4, sc_remove_hc                # Check if we have 4+ consecutive
            j sc_cont_while_hc

            sc_reset_count_hc:
            li $t3, 0                               # Reset tracked color
            li $t4, 0                               # Reset count
            j sc_cont_while_hc

            sc_remove_hc:
            lw $s7, BOTTLE_TL_X
            lw $s6, BOTTLE_TL_Y
            add $a0, $t2, $s7                       # Current position + offset
            add $a1, $t1, $s6
            sub $a0, $a0, $t4                       # Go back to start of sequence
            addi $a0, $a0, 1                        # Adjust for 0-based index
            move $a2, $t4                           # Length to remove
            jal remove_consecutives_h
            li $v0, 1                               # Set return value
            j sc_end

            sc_cont_while_hc:
            addi $t2, $t2, 1                        # Next column
            j sc_while_hc

        sc_end_hc:
        addi $t1, $t1, 1                        # Move to the next row
        j sc_while_h                            # Continue scanning horizontally

    sc_end_h:
    # Scan vertically (t1, t2)
    li $t2, 0                                           # t2 = column to be scanned
    sc_while_v: beq $t2, $t8, sc_end                   # Check if the column has reached the end
        li $t1, 0                                       # t1 = current row
        # t0 = the address to the current pixel (ADDR_GRID_START + t2 * 4 (t2 move horizontally))
        sll $t0, $t2, 2
        lw $s7, ADDR_GRID_START
        add $t0, $t0, $s7

        lw $t3, 0($t0)                                  # t3 = current pixel color
        li $t4, 0                                       # t4 = counter for number of consecutives with same colors
        sc_while_vc: beq $t1, $t7, sc_end_vc           # Check if end of column
            sll $s7, $t1, 7                            # Calculate vertical offset (row * 128)
            add $t5, $t0, $s7                          # Get current pixel address

            lw $s7, 0($t5)                             # Load current color
            beq $s7, $zero, sc_reset_count_vc          # If black, reset count

            # Check if colors match (including virus variants)
            STORE_TO_STACK($t0)
            STORE_TO_STACK($t1)
            STORE_TO_STACK($t2)
            STORE_TO_STACK($t3)
            STORE_TO_STACK($t4)
            STORE_TO_STACK($t5)
            move $a0, $t3                           # First color (tracked)
            move $a1, $s7                           # Second color (current)
            jal check_matching_colors
            RESTORE_FROM_STACK($t5)
            RESTORE_FROM_STACK($t4)
            RESTORE_FROM_STACK($t3)
            RESTORE_FROM_STACK($t2)
            RESTORE_FROM_STACK($t1)
            RESTORE_FROM_STACK($t0)

            beq $v0, 1, sc_increment_vc            # If colors match, increment

            # Different color (not black)
            move $t3, $s7                              # Track new color
            li $t4, 1                                  # Reset count to 1
            j sc_cont_while_vc

            sc_increment_vc:
            beq $t3, $zero, sc_cont_while_vc           # Skip if tracking black
            addi $t4, $t4, 1                           # Increment count
            lw $s7, 128($t5)                          # Load next color
            # Check if colors match (including virus variants)
            STORE_TO_STACK($t0)
            STORE_TO_STACK($t1)
            STORE_TO_STACK($t2)
            STORE_TO_STACK($t3)
            STORE_TO_STACK($t4)
            STORE_TO_STACK($t5)
            move $a0, $t3                           # First color (tracked)
            move $a1, $s7                           # Second color (current)
            jal check_matching_colors
            RESTORE_FROM_STACK($t5)
            RESTORE_FROM_STACK($t4)
            RESTORE_FROM_STACK($t3)
            RESTORE_FROM_STACK($t2)
            RESTORE_FROM_STACK($t1)
            RESTORE_FROM_STACK($t0)

            beq $v0, 1, sc_cont_while_vc            # If colors match, increment
            bge $t4, 4, sc_remove_vc                   # Check if we have 4+ consecutive
            j sc_cont_while_vc

            sc_reset_count_vc:
            li $t3, 0                                  # Reset tracked color
            li $t4, 0                                  # Reset count
            j sc_cont_while_vc

            sc_remove_vc:
            lw $s7, BOTTLE_TL_X
            lw $s6, BOTTLE_TL_Y
            add $a0, $t2, $s7                          # Current position + offset X
            add $a1, $t1, $s6                          # Current position + offset Y
            sub $a1, $a1, $t4                          # Go back to start of sequence
            addi $a1, $a1, 1                           # Adjust for 0-based index
            move $a2, $t4                              # Length to remove
            jal remove_consecutives_v
            li $v0, 1                                  # Set return value
            j sc_end

            sc_cont_while_vc:
            addi $t1, $t1, 1                           # Next row
            j sc_while_vc

        sc_end_vc:
        addi $t2, $t2, 1                               # Move to the next column
        j sc_while_v                                   # Continue scanning vertically

    sc_end:

    RESTORE_FROM_STACK($ra)
    jr $ra


##############################################################################
# Function to find the current address given X and Y coordinates
# Parameters:
# $a0 = X coordinate
# $a1 = Y coordinate

##############################################################################
# Function to return the current capsule pattern (1 or 2)
# Note: 1 means the pixel is colored, 0 means the pixel is black
# Pattern 1: 0 0
#            1 1
# Pattern 2: 1 0
#            1 0
# Return value: $v0 = 1 (pattern 1) or $v0 = 2 (pattern 2)
# Registers changed: $v0, $t1
get_pattern:
    lw $t1, CURR_CAPSULE_STATE      # $t1 = color of the top left pixel
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
# Registers changed: $v0, $t0, $t1, $t9, $s0
move_left:
    STORE_TO_STACK($ra)                 # Save the return address
    lw $t9, BLACK                       # $t9 = black
    # Check if the bottom left pixel of the capsule block can move 
    addi $t0, $s0, 128                  # $t0 = address of the bottom left pixel of the capsule block
    addi $t0, $t0, -4                   # $t0 = new address of the bottom left pixel of the capsule block after moving left
    lw $t1, 0($t0)                      # $t1 = color of the new address of the bottom left pixel of the capsule block
    bne $t1, $t9, ml_end                # Check if the new address of the bottom left pixel is occupied (isn't black)
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
        jal remove_capsule
        addi $s0, $s0, -4               # Move the capsule block left by 1 pixel
        jal draw_capsule
    ml_end:
        # Return to the calling program
        RESTORE_FROM_STACK($ra)         # Restore the return address
        jr $ra


##############################################################################
# Function to handle capsule movement to the right (pressing d)
# Assumption: The capsule position is valid before moving right
# Note: The capsule can only move right if there is nothing on the right
# Registers changed: $v0, $t0, $t1, $t9, $s0
move_right:
    STORE_TO_STACK($ra)                 # Save the return address
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
        jal remove_capsule
        addi $s0, $s0, 4                # Move the capsule block right by 1 pixel
        jal draw_capsule
    mr_end:
        # Return to the calling program
        RESTORE_FROM_STACK($ra)         # Restore the return address
        jr $ra


##############################################################################
# Function to handle capsule movement down (pressing s)
# Assumption: The capsule position is valid before moving down
# Note: The capsule can only move down if there is nothing below it
# Clarification: base bitmap = base address for bitmap (top left pixel of the bitmap)
# Registers changed: $v0, $t0, $t1, $t2, $t3, $t4 $t9, $s0
# Return value: $v0 = 1 if the capsule block can't move down, $v0 = 0 otherwise
move_down:
    STORE_TO_STACK($ra)                 # Save the return address
    lw $t9, BLACK                       # $t9 = black
    # Check if the bottom left pixel of the capsule block can move down
    addi $t0, $s0, 128                  # $t0 = address of the bottom left pixel of the capsule block
    addi $t0, $t0, 128                  # $t0 = new address of the bottom left pixel of the capsule block after moving down
    lw $t1, 0($t0)                      # $t1 = color of the new address of the bottom left pixel of the capsule block
    bne $t1, $t9, md_cant_move          # Check if the new address of the bottom left pixel is occupied (isn't black)
    # The bottom left pixel of the capsule block can move down
    # Check if other pixels of the capsule block can move down
    jal get_pattern                     # Get the pattern of the current capsule block
    beq $v0, 2, md_can_move             # Check if the pattern is 2
    # The pattern is 1
    # Check if the bottom right pixel of the capsule block can move down
    addi $t0, $s0, 132                  # $t0 = address of the bottom right pixel of the capsule block
    addi $t0, $t0, 128                  # $t0 = new address of the bottom right pixel of the capsule block after moving down
    lw $t1, 0($t0)                      # $t1 = color of the new address of the bottom right pixel of the capsule block
    bne $t1, $t9, md_cant_move          # Check if the new address of the bottom right pixel is occupied (isn't black)
    j md_can_move                       # The bottom right pixel of the capsule block also can move down

    md_can_move:
        jal remove_capsule              # Remove the current capsule block
        addi $s0, $s0, 128              # Move the capsule block down by 1 pixel
        jal draw_capsule                # Draw the capsule block at the new position
        li $v0, 0                       # $v0 = 0 since the capsule block can move down
        j md_end
    md_cant_move:
        # Store the offsets of both halves of the capsule block in AOCH
        jal get_pattern                 # Get the pattern of the current capsule block
        la $t0, ALLOC_OFFSET_CAPSULE_HALF
        beq $v0, 1, md_cant_move_1      # Check if the pattern is 1
        j md_cant_move_2                # The pattern is 2
        md_cant_move_1:
            # Find the offset of the bottom left and bottom right pixels, relative to the base bitmap
            move $t0, $s0               # $t0 = address of the top left pixel of the capsule block
            lw $t1, ADDR_DSPL           # $t1 = base address for display
            sub $t0, $t0, $t1           # $t0 = offset of the top left pixel from the base bitmap
            addi $t2, $t0, 128          # $t2 = offset of the bottom left pixel from the base bitmap
            addi $t3, $t0, 132          # $t3 = offset of the bottom right pixel from the base bitmap
            # Store the offsets in AOCH
            la $t1, ALLOC_OFFSET_CAPSULE_HALF   # $t1 = base address of AOCH
            add $t4, $t1, $t3           # $t4 = address of the bottom right pixel's AOCH
            sw $t2, 0($t4)              # Store the offset of the bottom left pixel in bottom right pixel's AOCH
            add $t4, $t1, $t2           # $t4 = address of the bottom left pixel's AOCH
            sw $t3, 0($t4)              # Store the offset of the bottom right pixel in bottom left pixel's AOCH
            j md_cant_move_end
        md_cant_move_2:
            # Find the offset of the top left and bottom left pixels, relative to the base bitmap
            move $t0, $s0               # $t0 = address of the top left pixel of the capsule block
            lw $t1, ADDR_DSPL           # $t1 = base address for display
            sub $t2, $t0, $t1           # $t2 = offset of the top left pixel from the base bitmap
            addi $t3, $t2, 128          # $t3 = offset of the bottom left pixel from the base bitmap
            # Store the offsets in AOCH
            la $t1, ALLOC_OFFSET_CAPSULE_HALF   # $t1 = base address of AOCH
            add $t4, $t1, $t3           # $t4 = address of the bottom left pixel's AOCH
            sw $t2, 0($t4)              # Store the offset of the top left pixel in bottom left pixel's AOCH
            add $t4, $t1, $t2           # $t4 = address of the top left pixel's AOCH
            sw $t3, 0($t4)              # Store the offset of the bottom left pixel in top left pixel's AOCH
            j md_cant_move_end
        md_cant_move_end:
            li $v0, 1                   # $v0 = 1 since the capsule block can't move down
            j md_end
    md_end:
        # Return to the calling program
        RESTORE_FROM_STACK($ra)         # Restore the return address
        jr $ra


##############################################################################
# Function to rotate the capsule block clockwise (pressing w)
# Assumption: The capsule position is valid before rotating
# Note: The capsule can only rotate if it doesn't collide with other blocks
# Registers changed: $v0, $t0, $t1, $t2, $t3, $t4, $t9
rotate:
    STORE_TO_STACK($ra)                 # Save the return address
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
        jal remove_capsule
        la $t0, CURR_CAPSULE_STATE      # $t0 = address of the top left pixel of the capsule block
        addi $t1, $t0, 8                # $t1 = address of the bottom left pixel of the capsule block
        lw $t2, 0($t1)                  # $t2 = color of the bottom left pixel of the capsule block
        addi $t3, $t0, 12               # $t3 = address of the bottom right pixel of the capsule block
        lw $t4, 0($t3)                  # $t4 = color of the bottom right pixel of the capsule block
        sw $t2, 0($t0)                  # Move the color of the bottom left pixel to the top left pixel
        sw $t4, 0($t1)                  # Move the color of the bottom right pixel to the bottom left pixel
        sw $t9, 0($t3)                  # Set the bottom right pixel to black
        jal draw_capsule
        j r_end
    r_can_rotate_2:
        # Rotate the capsule block from pattern 2 to pattern 1
        jal remove_capsule
        la $t0, CURR_CAPSULE_STATE      # $t0 = address of the top left pixel of the capsule block
        lw $t1, 0($t0)                  # $t1 = color of the top left pixel of the capsule block
        addi $t2, $t0, 8                # $t2 = address of the bottom left pixel of the capsule block
        lw $t3, 0($t2)                  # $t3 = color of the bottom left pixel of the capsule block
        addi $t4, $t0, 12               # $t4 = address of the bottom right pixel of the capsule block
        sw $t1, 0($t4)                  # Move the color of the top left pixel to the bottom left pixel
        sw $t9, 0($t0)                  # Set the top left pixel to black
        jal draw_capsule
        j r_end
    r_end:
        # Return to the calling program
        RESTORE_FROM_STACK($ra)         # Restore the return address
        jr $ra


##############################################################################
# Function to draw a vertical line on the display
# Assumption: the line can be drawn within the same column
# $a0 = X coordinate of the starting point
# $a1 = Y coordinate of the starting point
# $a2 = length of the line
# $a3 = color of the line
# Registers changed: $a0, $a1, $a2, $t0, $t1
draw_vertical_line:
    # Calculate the address of the starting point
    lw $t0, ADDR_DSPL                   # $t0 = base address for display
    sll $a0, $a0, 2                     # Calculate the X offset to add to $t0 (multiply $a0 by 4)
    sll $a1, $a1, 7                     # Calculate the Y offset to add to $t0 (multiply $a1 by 128)
    add $t0, $t0, $a0                   # Add the X offset to $t0.
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
# Registers changed: $a0, $a1, $a2, $t0, $t1
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

##############################################################################
# Function to check if the color is a virus's color
# Parameters: $a0 = pixel's color
is_virus_color:
    STORE_TO_STACK($ra)

    lw $t0, RED_VIRUS
    beq $a0, $t0, is_virus
    lw $t0, GREEN_VIRUS
    beq $a0, $t0, is_virus
    lw $t0, BLUE_VIRUS
    beq $a0, $t0, is_virus

    li $v0, 0          # Not a virus
    j is_virus_end
    is_virus:
        li $v0, 1          # Is a virus
    is_virus_end:
        RESTORE_FROM_STACK($ra)
        jr $ra

##############################################################################
# Function to remove consecutive lines (vertical)
# Assumption: The lines to be removed are consecutive
# Parameters:
# $a0 = X coordinate of the starting point
# $a1 = Y coordinate of the starting point
# $a2 = length of the line
# Registers changed: $ra, $v0, $a0, $a2
remove_consecutives_v:
    STORE_TO_STACK($ra)
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    la $t8, ALLOC_OFFSET_CAPSULE_HALF      # Load capsule matrix base address
    lw $s7, ADDR_DSPL                # Load display base address

    # Calculate start position
    sll $a0, $a0, 2                        # X offset (x * 4)
    sll $a1, $a1, 7                        # Y offset (y * 128)
    add $t0, $a0, $a1                      # Combined offset
    add $t0, $t8, $t0                      # t0 = capsule matrix address

    sll $t1, $a2, 7                        # Calculate length offset (length * 128 for vertical)
    add $t1, $t1, $t0                      # t1 = end address

    rcv_alter_capsule_matrix: beq $t0, $t1, rcv_alter_end            # Check if we've reached the end
        # Check if current position has a virus
        sub $t3, $t0, $t8        # Get offset from capsule matrix
        add $t3, $s7, $t3        # Get display address
        lw $t4, 0($t3)           # Load color

        # Check if it's a virus
        STORE_TO_STACK($t0)
        STORE_TO_STACK($t1)
        STORE_TO_STACK($t3)
        STORE_TO_STACK($t4)
        move $a0, $t4
        jal is_virus_color
        RESTORE_FROM_STACK($t4)
        RESTORE_FROM_STACK($t3)
        RESTORE_FROM_STACK($t1)
        RESTORE_FROM_STACK($t0)

        beq $v0, $zero, not_virus_v
        addi $s2, $s2, 1        # Increment virus counter if virus found
        addi $s1, $s1, -1       # Decrement total virus count

        not_virus_v:
        # Check if current position is part of a capsule
        lw $t2, 0($t0)                         # Load capsule reference
        beq $t2, $zero, rcv_next               # Skip if not part of capsule

        lw $t4, 0($t0)                         # Load reference again
        add $t7, $t4, $t8                      # Get other half reference
        sw $zero, 0($t7)                     # Clear other half reference
        sw $zero, 0($t0)                       # Clear current reference

    rcv_next:
        addi $t0, $t0, 128                     # Move to next row (128 bytes down)
        j rcv_alter_capsule_matrix

    rcv_alter_end:
    # Store parameters for animation
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    li $a3, 0x888888
    jal draw_vertical_line
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    STORE_TO_STACK($a0)
    li $v0, 32
    li $a0, 50
    syscall
    RESTORE_FROM_STACK($a0)

    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    li $a3, 0xaaaaaa
    jal draw_vertical_line
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    STORE_TO_STACK($a0)
    li $v0, 32
    li $a0, 50
    syscall
    RESTORE_FROM_STACK($a0)

    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    li $a3, 0x000000
    jal draw_vertical_line
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    RESTORE_FROM_STACK($ra)
    jr $ra


##############################################################################
# Function to remove consecutive lines (horizontal)
# Assumption: The lines to be removed are consecutive
# Parameters:
# $a0 = X coordinate of the starting point
# $a1 = Y coordinate of the starting point
# $a2 = length of the line
remove_consecutives_h:
    STORE_TO_STACK($ra)
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    la $t8, ALLOC_OFFSET_CAPSULE_HALF
    lw $s7, ADDR_DSPL                # Load display base address
    # Calculate start position
    sll $a0, $a0, 2                         # X offset
    sll $a1, $a1, 7                         # Y offset
    add $t0, $a0, $a1                       # Combined offset
    add $t0, $t8, $t0                       # Capsule matrix address

    sll $t1, $a2, 2                         # Calculate length offset
    add $t1, $t1, $t0                       # End address
    rch_alter_capsule_matrix:   beq $t0, $t1, rch_alter_end
        # Check if current position has a virus
        sub $t3, $t0, $t8        # Get offset from capsule matrix
        add $t3, $s7, $t3        # Get display address
        lw $t4, 0($t3)           # Load color

        # Check if it's a virus
        STORE_TO_STACK($t0)
        STORE_TO_STACK($t1)
        STORE_TO_STACK($t3)
        STORE_TO_STACK($t4)
        move $a0, $t4
        jal is_virus_color
        RESTORE_FROM_STACK($t4)
        RESTORE_FROM_STACK($t3)
        RESTORE_FROM_STACK($t1)
        RESTORE_FROM_STACK($t0)

        beq $v0, $zero, not_virus_h
        addi $s2, $s2, 1        # Increment virus counter if virus found
        addi $s1, $s1, -1       # Decrement total virus count

        not_virus_h:
        # Check if current position is part of a capsule
        lw $t2, 0($t0)                          # Load capsule reference
        beq $t2, $zero, rch_next                # Skip if not part of capsule

        lw $t4, 0($t0)                          # Load reference again
        add $t7, $t4, $t8                      # Get other half reference
        sw $zero, 0($t7)                     # Clear other half reference
        sw $zero, 0($t0)                        # Clear current reference
    rch_next:
        addi $t0, $t0, 4
        j rch_alter_capsule_matrix
    rch_alter_end:
    
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    li $a3, 0x888888
    jal draw_horizontal_line
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    STORE_TO_STACK($a0)
    li $v0, 32
    li $a0, 50
    syscall
    RESTORE_FROM_STACK($a0)

    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    li $a3, 0xaaaaaa
    jal draw_horizontal_line
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    STORE_TO_STACK($a0)
    li $v0, 32
    li $a0, 50
    syscall
    RESTORE_FROM_STACK($a0)

    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    li $a3, 0x000000
    jal draw_horizontal_line
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)
    
    RESTORE_FROM_STACK($ra)
    jr $ra


##############################################################################
# Function to draw the bottle
# Registers changed: $ra, $a0, $a1, $a2, $a3, $s6, $s7
draw_bottle:
    # Save the return address $ra
    STORE_TO_STACK($ra)
    
    # Draw the bottle
    lw $s6, GRID_WIDTH              # $s6 = width of the inside of the bottle
    lw $s7, GRID_HEIGHT             # $s7 = height of the inside of the bottle
    # Draw the top of the bottle
    li $a0, 6                       # $a3 = Starting X coordinate
    li $a1, 9                       # $a2 = Starting Y coordinate
    li $a2, 4                       # $a2 = Length of the line
    lw $a3, WHITE                   # $a3 = Colour
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    STORE_TO_STACK($a3)
    jal draw_vertical_line
    RESTORE_FROM_STACK($a3)
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    li $a0, 10                      # $a3 = Starting X coordinate
    li $a1, 9                       # $a2 = Starting Y coordinate
    li $a2, 4                       # $a2 = Length of the line
    lw $a3, WHITE                   # $a3 = Colour
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    STORE_TO_STACK($a3)
    jal draw_vertical_line
    RESTORE_FROM_STACK($a3)
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    li $a0, 2                       # $a3 = Starting X coordinate
    li $a1, 12                      # $a2 = Starting Y coordinate
    li $a2, 5                       # $a2 = Length of the line
    lw $a3, WHITE                   # $a3 = Colour
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    STORE_TO_STACK($a3)
    jal draw_horizontal_line
    RESTORE_FROM_STACK($a3)
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    li $a0, 10                      # $a3 = Starting X coordinate
    li $a1, 12                      # $a2 = Starting Y coordinate
    li $a2, 5                       # $a2 = Length of the line
    lw $a3, WHITE                   # $a3 = Colour
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
    li $a0, 2                       # $a3 = Starting X coordinate
    li $a1, 12                      # $a2 = Starting Y coordinate
    addi $a2, $s7, 2                # $a2 = Length of the line (height + 2)
    lw $a3, WHITE                   # $a3 = Colour
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    STORE_TO_STACK($a3)
    jal draw_vertical_line
    RESTORE_FROM_STACK($a3)
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    li $a0, 14                      # $a3 = Starting X coordinate
    li $a1, 12                      # $a2 = Starting Y coordinate
    addi, $a2, $s7, 2               # $a2 = Length of the line (height + 2)
    lw $a3, WHITE                   # $a3 = Colour
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    STORE_TO_STACK($a2)
    STORE_TO_STACK($a3)
    jal draw_vertical_line
    RESTORE_FROM_STACK($a3)
    RESTORE_FROM_STACK($a2)
    RESTORE_FROM_STACK($a1)
    RESTORE_FROM_STACK($a0)

    li $a0, 2                       # $a3 = Starting X coordinate
    li $a1, 29                      # $a2 = Starting Y coordinate
    addi $a2, $s6, 2                # $a2 = Length of the line (width + 2)
    lw $a3, WHITE                   # $a3 = Colour
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
# Registers changed: $ra, $v0, $a2, $a3, $t1
calculate_pixel_address:
    # Save return address
    STORE_TO_STACK($ra)

    li $t1, 0                   # t1 = 0
    # Calculate offset: y * 128 + x * 4
    sll $a2, $a2, 2             # $a2 *= 4
    sll $a3, $a3, 7             # $a3 *= 128
    add $t1, $t1, $a2           # Add x offset
    add $t1, $t1, $a3           # Add y offset

    # Calculate final address
    lw $v0, ADDR_DSPL
    add $v0, $v0, $t1

    # Restore return address
    RESTORE_FROM_STACK($ra)
    jr $ra


##############################################################################
# Function to initialize the capsule state
# Assumption: The capsule inside the capsule block are fit into empty space in the bitmap
# Registers changed: $t0, $t1
init_capsule_state:
    la $t0, NEXT_CAPSULE_STATE      # $t0 = base address

    # Initialize all positions with colors
    lw $t1, BLACK                   # Default color (or any other default)
    sw $t1, 0($t0)                  # Store in top position
    sw $t1, 4($t0)                  # Store in bottom position
    sw $t1, 8($t0)                  # Store in left position
    sw $t1, 12($t0)                 # Store in right position

    jr $ra


##############################################################################
# Function to set color at specific position
# Parameters:
# $a0 - position offset (0, 4, 8, or 12)
# $a1 - color to set
# Registers changed: $a1, $t0
set_capsule_color:
    la $t0, NEXT_CAPSULE_STATE      # $t0 = base address
    add $t0, $t0, $a0               # Add offset to base address
    sw $a1, 0($t0)                  # Store color at position
    jr $ra


##############################################################################
# Function to get color at specific position
# Parameters:
# $a0 - position offset (0, 4, 8, or 12)
# Returns:
# $v0 - color at position
# Registers changed: $v0, $t0
get_capsule_color:
    la $t0, CURR_CAPSULE_STATE      # $t0 = base address
    add $t0, $t0, $a0               # Add offset to base address
    lw $v0, 0($t0)                  # Load color from position
    jr $ra


##############################################################################
# Function to randomly set two colors at the starting point ($s0)
# Registers changed: $ra, $v0, $a0, $a1, $t2, $t3
generate_random_capsule_colors:
    # Save return address
    STORE_TO_STACK($ra)

    # Generate first random color
    jal generate_random_color           # Generate random color
    move $t2, $v0                       # $t2 = first color

    # Generate second random color
    jal generate_random_color           # Generate random color
    move $t3, $v0                       # $t3 = second color

    # Set top color
    li $a0, 0                           # $a0 = position offset for top color
    move $a1, $t2                       # $a1 = first random color
    jal set_capsule_color               # Set top color

    # Set bottom color
    li $a0, 8                           # $a0 = position offset for bottom color
    move $a1, $t3                       # $a1 = second random color
    jal set_capsule_color               # Set bottom color

    # Restore return address
    RESTORE_FROM_STACK($ra)
    jr $ra


##############################################################################
# Function to draw a capsule on the display
# The location of the capsule is stored in $s0
# The color of the 2x2 box for the capsule is stored in curr_capsule_state
# Return value: $v0 = 1 if can't add new capsule, $v0 = 0 otherwise
# Registers changed: $v0, $t0, $t1, $t2, $t3, $t4, $t5, $t9, $s0
draw_capsule:
    STORE_TO_STACK($ra)
    move $t0, $s0                   # Set the starting address for the capsule stored in $s0
    lw $t9, BLACK                   # $t9 = black
    jal get_pattern                 # Get the pattern of the current capsule block
    beq $v0, 1, dc_check_valid_1   # Check if the pattern is 1
    j dc_check_valid_2             # The pattern is 2
    dc_check_valid_1:
        lw $t1, 128($t0)            # $t1 = color of the bottom left pixel
        lw $t2, 132($t0)            # $t2 = color of the bottom right pixel
        bne $t1, $t9, dc_fail       # Check if the right pixel isn't black (non-empty)
        bne $t2, $t9, dc_fail       # Check if the left pixel isn't black (non-empty)
        j dc_valid                  # The capsule block is valid
    dc_check_valid_2:
        lw $t1, 0($t0)              # $t1 = color of the top left pixel
        lw $t2, 128($t0)            # $t2 = color of the bottom left pixel
        bne $t1, $t9, dc_fail       # Check if the right pixel isn't black (non-empty)
        bne $t2, $t9, dc_fail       # Check if the left pixel isn't black (non-empty)
        j dc_valid                  # The capsule block is valid
    dc_valid:
    la $t1, CURR_CAPSULE_STATE      # Set the current color palette
    lw $t2, 0($t1)                  # Set the top left color
    lw $t3, 4($t1)                  # Set the top right color
    lw $t4, 8($t1)                  # Set the bottom left color
    lw $t5, 12($t1)                 # Set the bottow right color
    beq $v0, 1, dc_draw_pattern_1   # Check if the pattern is 1
    j dc_draw_pattern_2             # The pattern is 2

    # start drawing
    dc_draw_pattern_1:
        sw $t4, 128($t0)            # Draw the bottom left pixel
        sw $t5, 132($t0)            # Draw the bottom right pixel
        li $v0, 0                   # Successfully added new capsule
        j dc_end
    dc_draw_pattern_2:
        sw $t2, 0($t0)              # Draw the top left pixel
        sw $t4, 128($t0)            # Draw the bottom left pixel
        li $v0, 0                   # Successfully added new capsule
        j dc_end
    dc_fail:
        li $v0, 1                   # Can't add new capsule
        j dc_end
    dc_end:
        RESTORE_FROM_STACK($ra)
        jr $ra


##############################################################################
# Function to remove the capsule from the display
# The location of the capsule is stored in $s0
# Registers changed: $v0, $t7, $t8, $s0
remove_capsule:
    STORE_TO_STACK($ra)
    move $t7, $s0               # t7 = starting address for the capsule stored in $s0
    lw $t8, BLACK               # t8 = black color

    jal get_pattern             # Get the pattern of the current capsule block
    beq $v0, 1, rc_pattern_1    # Check if the pattern is 1
    j rc_pattern_2              # The pattern is 2

    rc_pattern_1:
        sw $t8, 128($t7)        # Set the bottom left pixel to black
        sw $t8, 132($t7)        # Set the bottom right pixel to black
        j rc_end

    rc_pattern_2:
        sw $t8, 0($t7)          # Set the top left pixel to black
        sw $t8, 128($t7)        # Set the bottom left pixel to black
        j rc_end

    rc_end:
        RESTORE_FROM_STACK($ra)
        jr $ra


##############################################################################
# Function to draw a capsule on the display
# The location of the capsule is stored in ADDR_NEXT_CAPSULE
# The color of the 2x2 box for the capsule is stored in NEXT_CAPSULE_STATE
# Registers changed: $t0, $t1, $t2, $t3, $t4, $t5
draw_next_capsule:
    STORE_TO_STACK($ra)

    lw $t0, ADDR_NEXT_CAPSULE       # Set the starting address for the capsule stored in ADDR_NEXT_CAPSULE
    la $t1, NEXT_CAPSULE_STATE      # Set the current color palette
    lw $t2, 0($t1)                  # Set the top left color
    lw $t3, 4($t1)                  # Set the top right color
    lw $t4, 8($t1)                  # Set the bottom left color
    lw $t5, 12($t1)                 # Set the bottow right color

    sw $t2, 0($t0)                  # Draw the bottom left pixel
    sw $t3, 4($t0)                  # Draw the bottom right pixel
    sw $t4, 128($t0)                # Draw the top left pixel
    sw $t5, 132($t0)                # Draw the bottom left pixel

    RESTORE_FROM_STACK($ra)
    jr $ra


##############################################################################
# Function to set a new capsule to the next capsule state
# Registers changed: s0, t0, t1, t2, t3
set_new_capsule:
    # Set $s0 to start address
    lw $s0, ADDR_START_CAPSULE

    # Set the new capsule color
    la $t0, NEXT_CAPSULE_STATE
    la $t3, CURR_CAPSULE_STATE
    lw $t2, 0($t0)
    sw $t2, 0($t3)
    lw $t2, 4($t0)
    sw $t2, 4($t3)
    lw $t2, 8($t0)
    sw $t2, 8($t3)
    lw $t2, 12($t0)
    sw $t2, 12($t3)
        
    jr $ra

##############################################################################
# Function to return random color
# Return value: $v0 = color generated
# Registers changed: $v0, $a0, $a1
generate_random_color:
    # Generate a random number from 0 - 2 inclusive, and put the result in $a0
    li $v0, 42                      # syscall 42: generate random number
    li $a0, 0                       # Random number generated from 0
    li $a1, 3                       # to 2 inclusive
    syscall

    beq $a0, 0, return_red          # Check if the random number is 0
    beq $a0, 1, return_green        # Check if the random number is 1
    beq $a0, 2, return_blue         # Check if the random number is 2
    lw $v0, WHITE                   # Return white color

    j grc_end

    return_red:
        lw $v0, RED                 # Return red color
        j grc_end

    return_green:
        lw $v0, GREEN               # Return green color
        j grc_end

    return_blue:
        lw $v0, BLUE                # Return blue color
        j grc_end

    grc_end:
        jr $ra


##############################################################################
# Function to return random virus color
# Return value: $v0 = color generated
# Registers changed: $v0, $a0, $a1
generate_random_virus_color:
    # Generate a random number from 0 - 2 inclusive, and put the result in $a0
    li $v0, 42                      # syscall 42: generate random number
    li $a0, 0                       # Random number generated from 0
    li $a1, 3                       # to 2 inclusive
    syscall

    beq $a0, 0, return_dark_red     # Check if the random number is 0
    beq $a0, 1, return_dark_green   # Check if the random number is 1
    beq $a0, 2, return_dark_blue    # Check if the random number is 2

    return_dark_red:
        lw $v0, RED_VIRUS           # Return dark red color
        j grvc_end
    return_dark_green:
        lw $v0, GREEN_VIRUS         # Return dark green color
        j grvc_end
    return_dark_blue:
        lw $v0, BLUE_VIRUS          # Return dark blue color
        j grvc_end
    grvc_end:
        jr $ra


##############################################################################
# Function to draw viruses
# Assumption: There's nothing on the grid right now
# Registers changed: $ra, $v0, $a0, $a1, $t0, $t1, $t2, $t3, $t4, $t5, $t6
draw_viruses:
    STORE_TO_STACK($ra)
    li $t5, 0                                           # $t5 = loop counter
    lw $t6, VIRUS_COUNT                                 # $t6 = number of viruses
    dv_loop:
        dv_generate_addr_loop:
            # Generate random X offset for the new virus
            li $v0, 42                                  # syscall 42: generate random number
            li $a0, 0                                   # $a0 = lower bound of the random number
            lw $a1, POSSIBLE_VIRUS_POSITION_WIDTH       # $a1 = upper bound of the random number
            syscall
            move $t0, $a0                               # $t0 = random X offset
            sll $t0, $t0, 2                             # $t0 = random X offset in pixels
            # Generate random Y offset for the new virus
            li $v0, 42                                  # syscall 42: generate random number
            li $a0, 0                                   # $a0 = lower bound of the random number
            lw $a1, POSSIBLE_VIRUS_POSITION_HEIGHT      # $a1 = upper bound of the random number
            syscall
            move $t1, $a0                               # $t1 = random Y offset
            sll $t1, $t1, 7                             # $t1 = random Y offset in pixels
            # Calculate the address of the new virus
            lw $t2, ADDR_VIRUS_STARTING_POINT           # $t2 = starting address of the virus
            add $t2, $t2, $t0
            add $t2, $t2, $t1                           # $t2 = address of the new virus
            # Check if the new address is not occupied
            lw $t3, 0($t2)                              # $t3 = color of the new address
            lw $t4, BLACK                               # $t4 = black
            bne $t3, $t4, dv_generate_addr_loop         # Check if the new address is occupied
            # The new address is not occupied, proceed to draw the virus
        # Generate random color for the new virus
        jal generate_random_virus_color
        move $t3, $v0                               # $t3 = random virus color
        # Draw the new virus
        sw $t3, 0($t2)
        # Repeat until the number of viruses is reached
        addi $t5, $t5, 1                            # Increment the loop counter
        bne $t5, $t6, dv_loop                       # Repeat until the number of viruses is reached
    dv_end:
        RESTORE_FROM_STACK($ra)
        jr $ra


##############################################################################
# Function to check for falling capsules (in the entire bottle)
# Run a single vertical scan (from bottom to top) for each column, from the
# leftmost column to the rightmost column
# Registers changed: $ra, $a0, $a1, $s3, $t0, $t1, $t2, $s3, $s4 $s5, $s6, $s7
# Persistent registers (throughout this function):
# - $s3 = 1 if current outer loop has at least one falling capsule, 0 otherwise
# - $s4 = offset of the current capsule position, relative to base bitmap
# - $s5 = offset of the other half of the current capsule position, relative to base bitmap (if applicable)
# - $s6 = column counter (from left to right)
# - $s7 = row counter (from bottom to top)
# Clarification: 
# - base bottle = top left pixel of the bottle
# - base bitmap = base address for bitmap (top left pixel of the bitmap)
# Return value: $v1 = 1 if there is at least one falling capsule, 0 otherwise
scan_falling_capsules:
    li $v1, 0                                   # $v1 = 0 (reset return value)
    STORE_TO_STACK($ra)
    STORE_TO_STACK($s3)
    STORE_TO_STACK($s4)
    STORE_TO_STACK($s5)
    STORE_TO_STACK($s6)
    STORE_TO_STACK($s7)

    sfc_main_loop:
        # Loop through each column (from 0 to GRID_WIDTH - 1)
        li $s6, 0                               # $s6 = column counter (from left to right)
        li $s3, 0                               # $s3 = 0 (reset the flag for falling capsules)
        sfc_col_loop:
            lw $s7, GRID_HEIGHT                 # $s7 = height of the inside of the bottle
            addi $s7, $s7, -1                   # $s7 = row counter (from bottom to top)
            # Loop through each row (from GRID_HEIGHT - 1 to 0)
            sfc_row_loop:
                sll $t1, $s6, 2                     # $t1 = X offset, relative to base bottle
                sll $t2, $s7, 7                     # $t2 = Y offset, relative to base bottle
                add $s4, $t1, $t2                   # $s4 = offset of the current capsule, relative to base bottle
                lw $t0, OFFSET_FROM_TOP_LEFT        # $t0 = offset of base bottle, relative to base bitmap
                add $s4, $s4, $t0                   # $s4 = offset of the current capsule, relative to base bitmap

                # Find address of the current capsule
                lw $t1, ADDR_DSPL                   # $t1 = base address for display
                add $t1, $t1, $s4                   # $t1 = address of the current capsule

                # Check if current pixel is a capsule (either RED, GREEN, or BLUE)
                lw $t0, 0($t1)                      # $t0 = color of the current pixel
                lw $t1, RED                         # $t1 = red
                beq $t0, $t1, sfc_start_row_loop    # Check if the current pixel is red
                lw $t1, GREEN                       # $t1 = green
                beq $t0, $t1, sfc_start_row_loop    # Check if the current pixel is green
                lw $t1, BLUE                        # $t1 = blue
                beq $t0, $t1, sfc_start_row_loop    # Check if the current pixel is blue
                j sfc_row_loop_end                  # The current pixel is not a capsule

                sfc_start_row_loop:
                # Find address of the other half of the current capsule
                la $s5, ALLOC_OFFSET_CAPSULE_HALF   # $s5 = pointer to offset of the other half of the top left pixel, relative to base bitmap
                add $s5, $s5, $s4                   # $s5 = pointer to offset of the other half of the current pixel, relative to base bitmap
                lw $s5, 0($s5)                      # $s5 = offset of the other half of the current pixel, relative to base bitmap      
                lw $t0, ADDR_DSPL                   # $t0 = base address for display
                add $t2, $t0, $s5                   # $t2 = address of the other half of the current pixel
                beq $t2, $zero, sfc_half_capsule    # Check if the other half of the current capsule doesn't exist (i.e. this is a half capsule)
                j sfc_full_capsule                  # The other half of the current capsule exist

                sfc_half_capsule:
                    move $a0, $s4                   # $a0 = offset of the current capsule, relative to base bitmap
                    jal move_down_half_capsule      # Move the current capsule down by 1 pixel until it can't move down anymore
                    beq $v0, 1, sfc_falling         # Check if there is at least one falling capsule
                    j sfc_row_loop_end

                sfc_full_capsule:
                    move $a0, $s4                   # $a0 = offset of the current capsule, relative to base bitmap
                    move $a1, $s5                   # $a1 = offset of the other half of the current capsule, relative to base bitmap
                    jal move_down_full_capsule      # Move the current capsule and its other half down by 1 pixel until they can't move down anymore
                    beq $v0, 1, sfc_falling         # Check if there is at least one falling capsule
                    j sfc_row_loop_end

                sfc_falling:
                    li $s3, 1                       # At least one falling capsule in the current column
                    j sfc_row_loop_end

                sfc_row_loop_end:
                    addi $s7, $s7, -1               # Move to the next row (decrement the row counter)
                    bne $s7, -1, sfc_row_loop       # Repeat until the top row is reached
            lw $t0, GRID_WIDTH                      # $t0 = width of the inside of the bottle
            addi $s6, $s6, 1                        # Move to the next column (increment the column counter)
            bne $s6, $t0, sfc_col_loop              # Repeat until the rightmost column is reached

    bne $s3, $zero, sfc_next_loop                   # Check if there is at least one falling capsule
    j sfc_end                                       # There's no falling capsule, end the loop
    sfc_next_loop:
        li $v1, 1                                   # $v1 = 1 since there is at least one falling capsule
        j sfc_main_loop                             # Repeat until there's no falling capsule
    sfc_end:
        RESTORE_FROM_STACK($s7)
        RESTORE_FROM_STACK($s6)
        RESTORE_FROM_STACK($s5)
        RESTORE_FROM_STACK($s4)
        RESTORE_FROM_STACK($s3)
        RESTORE_FROM_STACK($ra)
        jr $ra


##############################################################################
# Function to move a half capsule down by 1 pixel until it can't move down anymore
# Parameters: $a0 = half capsule's offset, relative to base bitmap
# Return value: $v0 = 1 if at least the half capsule move once, $v0 = 0 otherwise
# Registers changed: $v0, $t0, $t1, $t2, $t3
# Clarification:
# - base = top left pixel of the bottle
# - base bitmap = base address for display (top left pixel of the bitmap)
# - half capsule: the half capsule that is being moved down
move_down_half_capsule:
    STORE_TO_STACK($a0)
    li $v0, 0                           # $v0 = 0
    # Set $t0 = address of the half capsule on the bitmap
    lw $t0, ADDR_DSPL                   # $t0 = base address for display
    add $t0, $t0, $a0                   # $t0 += the half capsule's offset from the base
    mdhc_loop:
        lw $t1, 0($t0)                  # $t1 = color of the half capsule
        lw $t2, BLACK                   # $t2 = black
        lw $t3, 128($t0)                # $t3 = color of the pixel below the half capsule
        bne $t3, $t2, mdhc_end          # Check if the pixel below the half capsule is occupied
        # The pixel below the half capsule is empty, move the half capsule down by 1 pixel
        li $v0, 1                       # At least the half capsule move once, set return value to 1
        sw $t1, 128($t0)                # Draw the color of the half capsule at the new position
        sw $t2, 0($t0)                  # Draw black in the current pixel
        addi $t0, $t0, 128              # $t0 = new address of the half capsule

        # Sleep for a while
        STORE_TO_STACK($v0)
        li $v0, 32                      # syscall 32: sleep
        li $a0, 100                     # Sleep for 100 ms
        syscall
        RESTORE_FROM_STACK($v0)

        j mdhc_loop                     # Repeat until the half capsule can't move down anymore
    mdhc_end:
        RESTORE_FROM_STACK($a0)
        jr $ra


##############################################################################
# Function to move a half capsule and its other half down by 1 pixel until they can't move down anymore
# Note: Also update the ALLOC_OFFSET_CAPSULE_HALF to the new position of both half capsules
# Parameters:
# - $a0 = half capsule's offset from the base bitmap
# - $a1 = other half capsule's offset from the base bitmap
# Return value: $v0 = 1 if at least the half capsule move once, $v0 = 0 otherwise
# Registers changed: $v0, $t0, $t1, $t2, $t3, $t4, $t5, $t6, $t7
# Clarification:
# - base = top left pixel of the bottle
# - base bitmap = base address for display (top left pixel of the bitmap)
# - half capsule: the half capsule that is being moved down
move_down_full_capsule:
    STORE_TO_STACK($a0)
    STORE_TO_STACK($a1)
    li $v0, 0                               # $v0 = 0
    # Set $t0 = address of the half capsule on the bitmap
    lw $t0, ADDR_DSPL                       # $t0 = base address for display
    add $t0, $t0, $a0                       # $t0 += the half capsule's offset from the base
    # Set $t1 = address of the other half capsule on the bitmap
    lw $t1, ADDR_DSPL                       # $t1 = base address for display
    add $t1, $t1, $a1                       # $t1 += the other half capsule's offset from the base

    # Check if the capsule is in vertical position
    sub $t2, $t1, $t0                       # $t2 = $t1 - $t0
    beq $t2, 128, mdfc_loop_vertical        # Check if $t1 is below $t0 => vertical
    sub $t2, $t0, $t1                       # $t2 = $t0 - $t1
    beq $t2, 128, mdfc_vertical_swap        # Check if $t0 is below $t1 => vertical
    j mdfc_loop_horizontal                  # The half capsule is in horizontal position

    mdfc_vertical_swap:
        move $t2, $t0                       # $t2 = $t0
        move $t0, $t1                       # $t0 = $t1
        move $t1, $t2                       # $t1 = $t0
        j mdfc_loop_vertical                # Swap to make sure $t0 is above $t1 before going to the loop
    
    mdfc_loop_vertical:
        # Format: $t0
        #         $t1 ($t0 above $t1)
        lw $t2, 0($t0)                      # $t2 = color of the upper half capsule
        lw $t3, 0($t1)                      # $t3 = color of the lower half capsule
        lw $t4, 128($t1)                    # $t4 = color of the pixel below the full capsule
        lw $t5, BLACK                       # $t5 = black
        bne $t4, $t5, mdfc_end              # Check if the pixel below the full capsule is occupied
        # The pixel below the full capsule is empty, check if the other half of the full capsule can move down
        li $v0, 1                           # At least the half capsule move once, set return value to 1
        sw $t5, 0($t0)                      # Draw black in the current pixel
        sw $t2, 128($t0)                    # Draw the color of the upper half capsule at the new position
        sw $t3, 128($t1)                    # Draw the color of the lower half capsule at the new position
        # Update the ALLOC_OFFSET_CAPSULE_HALF to the new position of both half capsules
        addi $t0, $t0, 128                  # $t0 = new address of the upper half capsule
        addi $t1, $t1, 128                  # $t1 = new address of the lower half capsule
        la $t2, ALLOC_OFFSET_CAPSULE_HALF   # $t2 = pointer to base address in AOCH
        add $t3, $t2, $a0                   # $t3 = pointer to old offset of the upper half capsule in AOCH
        add $t4, $t2, $a1                   # $t4 = pointer to old offset of the lower half capsule in AOCH
        sw $zero, 0($t3)                    # Set the old offset of the lower half capsule to 0
        sw $zero, 0($t4)                    # Set the old offset of the upper half capsule to 0
        lw $t5, ADDR_DSPL                   # $t5 = base address for display
        sub $t6, $t0, $t5                   # Convert first address to offset
        sub $t7, $t1, $t5                   # Convert second address to offset
        sw $t6, 128($t3)                    # Set the new offset of the upper half capsule to reflect new position
        sw $t7, 128($t4)                    # Set the new offset of the lower half capsule to reflect new position

        # Sleep for a while
        STORE_TO_STACK($v0)
        li $v0, 32                          # syscall 32: sleep
        li $a0, 100                         # Sleep for 100 ms
        syscall
        RESTORE_FROM_STACK($v0)

        j mdfc_loop_vertical                # Repeat until the half capsule and its other half can't move down anymore

    mdfc_loop_horizontal:
        lw $t2, 0($t0)                      # $t2 = color of the half capsule
        lw $t3, BLACK                       # $t3 = black
        lw $t4, 128($t0)                    # $t4 = color of the pixel below the half capsule
        bne $t4, $t3, mdfc_end              # Check if the pixel below the half capsule is occupied
        # The pixel below the half capsule is empty, check if the other half of the half capsule can move down
        lw $t4, 0($t1)                      # $t4 = color of the other half capsule
        lw $t5, 128($t1)                    # $t5 = color of the pixel below the other half capsule
        bne $t5, $t3, mdfc_end              # Check if the pixel below the other half of the half capsule is occupied
        # The pixel below the other half of the half capsule is empty, move the half capsule and its other half down by 1 pixel
        li $v0, 1                           # At least the half capsule move once, set return value to 1
        sw $t2, 128($t0)                    # Draw the color of the half capsule at the new position
        sw $t3, 0($t0)                      # Draw black in the current pixel
        sw $t4, 128($t1)                    # Draw the color of the other half of the half capsule at the new position
        sw $t3, 0($t1)                      # Draw black in the current pixel
        # Update the ALLOC_OFFSET_CAPSULE_HALF to the new position of both half capsules
        addi $t0, $t0, 128                  # $t0 = new address of the half capsule
        addi $t1, $t1, 128                  # $t1 = new address of the other half capsule
        la $t2, ALLOC_OFFSET_CAPSULE_HALF   # $t2 = pointer to base address in AOCH
        add $t3, $t2, $a0                   # $t3 = pointer to old offset of the half capsule in AOCH
        add $t4, $t2, $a1                   # $t4 = pointer to old offset of the other half capsule in AOCH
        sw $zero, 0($t3)                    # Set the old offset of the other half capsule to 0
        sw $zero, 0($t4)                    # Set the old offset of the half capsule to 0
        lw $t5, ADDR_DSPL                   # $t5 = base address for display
        sub $t6, $t0, $t5                   # Convert first address to offset
        sub $t7, $t1, $t5                   # Convert second address to offset
        sw $t6, 128($t3)                    # Set the new offset of the half capsule to reflect new position
        sw $t7, 128($t4)                    # Set the new offset of the other half capsule to reflect new position

        # Sleep for a while
        STORE_TO_STACK($v0)
        li $v0, 32                          # syscall 32: sleep
        li $a0, 100                         # Sleep for 100 ms
        syscall
        RESTORE_FROM_STACK($v0)

        j mdfc_loop_horizontal              # Repeat until the half capsule and its other half can't move down anymore
    mdfc_end:
        RESTORE_FROM_STACK($a1)
        RESTORE_FROM_STACK($a0)
        jr $ra


##############################################################################
# Function to draw pause icon at the top left corner of the screen
# Registers changed: $t0, $t1
draw_pause:
    lw $t0, ADDR_DSPL                   # $t0 = base address for display
    lw $t1, WHITE                       # $t1 = white
    sw $t1, 16($t0)
    sw $t1, 20($t0)
    sw $t1, 24($t0)
    sw $t1, 140($t0)
    sw $t1, 156($t0)
    sw $t1, 264($t0)
    sw $t1, 288($t0)
    sw $t1, 388($t0)
    sw $t1, 400($t0)
    sw $t1, 408($t0)
    sw $t1, 420($t0)
    sw $t1, 516($t0)
    sw $t1, 528($t0)
    sw $t1, 536($t0)
    sw $t1, 548($t0)
    sw $t1, 648($t0)
    sw $t1, 672($t0)
    sw $t1, 780($t0)
    sw $t1, 796($t0)
    sw $t1, 912($t0)
    sw $t1, 916($t0)
    sw $t1, 920($t0)
    jr $ra


##############################################################################
# Function to delete pause icon from the top left corner of the screen
delete_pause:
    lw $t0, ADDR_DSPL                   # $t0 = base address for display
    lw $t1, BLACK                       # $t1 = black
    sw $t1, 16($t0)
    sw $t1, 20($t0)
    sw $t1, 24($t0)
    sw $t1, 140($t0)
    sw $t1, 156($t0)
    sw $t1, 264($t0)
    sw $t1, 288($t0)
    sw $t1, 388($t0)
    sw $t1, 400($t0)
    sw $t1, 408($t0)
    sw $t1, 420($t0)
    sw $t1, 516($t0)
    sw $t1, 528($t0)
    sw $t1, 536($t0)
    sw $t1, 548($t0)
    sw $t1, 648($t0)
    sw $t1, 672($t0)
    sw $t1, 780($t0)
    sw $t1, 796($t0)
    sw $t1, 912($t0)
    sw $t1, 916($t0)
    sw $t1, 920($t0)
    jr $ra


##############################################################################
# Function to handle pause screen
handle_pause:
    STORE_TO_STACK($ra)
    jal draw_pause
    pause_loop:
        lw $t0, ADDR_KBRD                   # $t0 = base address for keyboard
        lw $t1, 0($t0)                      # $t1 = first word from keyboard
        bne $t1, 1, pause_loop              # If the first key is not 1, no key is pressed
        # A key is pressed, check if it is p (pause key)
        lw $t1, 4($t0)                  # $t1 = keyboard input
        beq $t1, 0x70, pause_end        # If the key is p, end the pause screen
        j pause_loop
    pause_end:
        jal delete_pause
        RESTORE_FROM_STACK($ra)
        jr $ra