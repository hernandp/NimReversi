# Copyright (c) 2019 Hernán Di Pietro

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import terminal, random, strscans, sequtils, strformat, os, times

type 
    GameState = enum
        gsMainMenu, gsTurn, gsThinking, gsEndGame

    BoardCellContent = enum
        bcWhite = "O", bcBlack = "X", bcEmpty = "."

    Player = enum
        plWhite = "White", plBlack = "Black"

    CellCoord = tuple[row: int, col: int]

    BoardCell = object
        content: BoardCellContent
        reverseCells: seq[CellCoord]

    PlayerKind = enum
        pkHuman, pkComputer

const
    BOARD_WIDTH = 8
    BOARD_HEIGHT = 8
    CPU_THINKING_TIME_RANGE_MS = (min: 100, max: 1000)

var
    gameState:      GameState
    running:        bool
    turn:           Player
    board:          array[0..(BOARD_WIDTH*BOARD_HEIGHT)-1, BoardCell]
    playerKind:     array[0..1, PlayerKind]
    scoreBoard:     tuple[black: int, white: int]
    currentMenuOpt: range[0..3]
    currentCursor:  CellCoord
    lastPlayerAvailMoves: int
    thisPlayerAvailMoves: int

proc setCellContent(row: int, col: int, what: BoardCellContent) =
    board[row * BOARD_WIDTH + col].content = what
    if what != bcEmpty:
        board[row * BOARD_WIDTH + col].reverseCells = @[]

proc getCellContent(row: int, col: int) : BoardCellContent =
    return board[row * BOARD_WIDTH + col].content

proc getCell(row:int, col: int) : BoardCell =
    return board[row * BOARD_WIDTH + col]

proc otherPlayer(p: Player) : Player =
    result = if p == plWhite: plBlack else: plWhite

proc isPlayerCell(p: Player, row: int, col: int) : bool =
    result = ord(getCellContent(row, col)) == ord(p)

proc cellInBoard(row: int, col: int) : bool = 
    result = row >= 0 and row < 8 and col >= 0 and col < 8

proc getIndexFromCoord(row: int, col: int): int =
    return row * BOARD_WIDTH + col
    
#
# Initialize game board and scores
#
proc initBoard() =
    for i in 0..board.len-1:
        board[i].content = bcEmpty
    
    setCellContent(3, 3, bcWhite)
    setCellContent(3, 4, bcBlack)
    setCellContent(4, 3, bcBlack)
    setCellContent(4, 4, bcWhite)

    scoreBoard = (black: 2, white: 2)

#
# Print the current board, along scores
#
proc drawInGameScreen() =

    const thinkingChars = @[ '/', '-', '\\', '|' ]
    var currentThinkingChar {.global.} : range[0..len(thinkingChars)] = 0
    
    stdout.setCursorPos(1,1)
    stdout.styledWrite(bgGreen, fgBlack,"    A  B  C  D  E  F  G  H ")
    
    for thisRow in 0..BOARD_HEIGHT - 1:
        stdout.setCursorPos(1, thisRow + 2)
        stdout.styledWrite(bgGreen, fgBlack, " " & $( thisRow + 1 ) & " ")
        for thisCol in 0..BOARD_WIDTH - 1:
            let idx = getIndexFromCoord(thisRow, thisCol)
            # let revCells = board[idx].reverseCells
            # if (len(revCells) > 0):
            #     stdout.write($(len(revCells)) & "  ")
            # else:

            let oddRow = if thisRow mod 2 == 0 : 0 else: 1
            stdout.setCursorPos(4 + thisCol * 3, thisRow + 2)   

            var backColor : BackgroundColor
            if playerKind[ord(turn)] == pkHuman and currentCursor.row == thisRow and currentCursor.col == thisCol:
                backColor = bgRed
            else:
                backColor = if (idx + oddRow) mod 2 == 0: bgMagenta else: bgCyan

            stdout.styledWrite(backColor, 
                if getCellContent(thisRow, thisCol) == bcWhite: fgWhite else: fgBlack,
                if getCellContent(thisRow, thisCol) == bcEmpty: "   " else: " O ")

    cursorDown(2)
    setCursorXPos(1)
    if gameState == gsEndGame:
        stdout.styledWrite(bgWhite, fgBlack, " WINNER ")
    else:
        stdout.styledWrite(bgGreen, fgBlack, "  TURN  ")
    
    if gameState == gsThinking:
        stdout.styledWrite(bgRed, fgWhite, "  THINKING " )
    else:
        stdout.styledWrite(bgBlue, fgWhite,"           " )
    
    stdout.styledWriteLine(bgGreen, fgBlack, " SCORES ")

    setCursorXPos(1)
    if gameState == gsEndGame:
        if scoreBoard.white > scoreBoard.black:
            stdout.styledWrite(bgWhite, fgBlack, " WHITE  ")
        elif scoreBoard.black > scoreBoard.white:
            stdout.styledWrite(bgBlack, fgWhite, " BLACK  ")
        else:
            stdout.styledWrite(bgMagenta, fgWhite, "  DRAW  ")

    else:
        if turn == plWhite:
            stdout.styledWrite(bgWhite, fgBlack, " WHITE  ")
        else:
            stdout.styledWrite(bgBlack, fgWhite, " BLACK  ")
        
    if gameState == gsThinking:
        stdout.styledWrite(bgRed, fgWhite, "      " & thinkingChars[currentThinkingChar] & "    "  )
        currentThinkingChar = (currentThinkingChar + 1) mod len(thinkingChars)
    else:
        stdout.styledWrite(bgBlue, fgWhite, "           " )

    stdout.styledWrite(bgBlack, fgWhite, " " & fmt"{scoreBoard.black:02}" & " ")
    stdout.styledWriteLine(bgWhite, fgBlack, " " & fmt"{scoreBoard.white:02}" & " ")

    cursorDown(1)
    setCursorXPos(1)

    if gameState == gsEndGame:
        stdout.styledWriteLine(bgGreen, fgWhite, "       Game Finished       ")
        setCursorXPos(1)
        stdout.styledWriteLine(bgGreen, fgBlack, "   Press any key to exit   ")
        stdout.styledWriteLine(bgBlue, fgBlack,  "                            ")
        stdout.styledWriteLine(bgBlue, fgBlack,  "                            ")
        stdout.styledWriteLine(bgBlue, fgBlack,  "                            ")
    else:    
        stdout.styledWriteLine(bgGreen, fgBlack, "          Controls         ")
        setCursorXPos(1)
        stdout.styledWriteLine(bgCyan, fgWhite, "   A W S D   ", bgMagenta, " Move Cursor  ")
        setCursorXPos(1)
        stdout.styledWriteLine(bgCyan, fgWhite, "    ENTER    ", bgMagenta, " Place Disc   ")
        setCursorXPos(1)
        stdout.styledWriteLine(bgCyan, fgWhite, "     ESC     ", bgMagenta,"     Exit     ")

#
# Flip (overthrow) a disc in the board
#
proc flipCell(row: int, col: int) =
    assert(getCellContent(row, col) != bcEmpty)
    setCellContent(row, col, if getCellContent(row,col) == bcWhite: bcBlack else: bcWhite)

#
# Lookup how many discs can be overthrown in a specified direction (rowStep/colStep)
#
proc lookupDiscsToReverse(turn: Player, row: int, col: int, rowStep: int, colStep: int, 
    cellsToReverse: var seq[CellCoord]) : bool =
    
    # Found empty cell or out of board, finish recursion with failed result
    if not cellInBoard(row, col):
        return false

    if getCellContent(row, col) == bcEmpty:
        return false

    # Own disc found, finish recursion with successful result
    if isPlayerCell(turn, row, col):
        return true

    # Keep looking in dx/dy vector
    let r = lookupDiscsToReverse(turn, row + rowStep, col + colStep, rowStep, colStep, cellsToReverse)
    if r:
        cellsToReverse.add((row,col))
    
    return r

#
# Place a player disc in the board
#
proc placeDisc(row: int, col: int) : bool =
    if getCellContent(row, col) != bcEmpty:
        echo "Cell not empty!"
        return false
    
    let cellsToReverse = getCell(row, col).reverseCells  
    
    # echo "DEBUG: " & $(cellsToReverse.len()) & " at r=" & $(row) & " c=" & $(col)
     
    if len(cellsToReverse) > 0:
        setCellContent(row, col, BoardCellContent(ord(turn)))
        for cell in cellsToReverse:
            flipCell(cell.row, cell.col)
        return true
    
    return false

#
# Scan for all discs that can be reversed in the
# eight directions (up, down, left, right, up-down, up-left, down-right, down-left)
# from a specific board cell
#
proc scanDiscsToReverse(row: int, col: int): seq[CellCoord] =
    var cellsToReverse: seq[CellCoord]
    for dx in @[0, 1, -1]:
        for dy in @[0, 1, -1]:
            if (dx == 0 and dy == 0):
                continue;
            discard lookupDiscsToReverse(turn, row + dx, col + dy, dx, dy, cellsToReverse)
    
    return cellsToReverse    

#
# Scans all board for the number of available overthrows of 
# opponent pieces for each empty cell.  
#
# Returns total move count in board.
#
proc scanBoard() : int =
    var 
        cellsToReverse: seq[CellCoord]
        totalMoveCount : int

    totalMoveCount = 0
    scoreBoard = (0,0)
    for thisCol in 0..BOARD_WIDTH - 1:
        for thisRow in 0..BOARD_HEIGHT - 1:
            if getCellContent(thisRow, thisCol) == bcEmpty:
                cellsToReverse = scanDiscsToReverse(thisRow, thisCol)
                board[getIndexFromCoord(thisRow, thisCol)].reverseCells = cellsToReverse
                totalMoveCount += len(cellsToReverse)
            else:
                if getCellContent(thisRow, thisCol) == bcWhite:
                    scoreBoard.white += 1
                else:
                    scoreBoard.black += 1
    return totalMoveCount

#
# Evaluate a CPU Turn. 
# This dumb AI will filter out the cells with better score,
# and pick one randomly if there are many to choose from.
#
proc evaluateCpuTurn() : CellCoord = 
    var
        topScore: int
        cellsToEval: seq[tuple[coord: CellCoord, score: int]]

    topScore = 0;
    for thisCol in 0..BOARD_WIDTH - 1:
        for thisRow in 0..BOARD_HEIGHT - 1:
            let cellScore = len(getCell(thisRow , thisCol).reverseCells)
            if cellScore > 0 and cellScore >= topScore:
                cellsToEval.insert( (coord: (row: thisRow, col: thisCol), score: cellScore), 0)
                topScore = cellScore
    
    # echo "found alternatives: "
    # for i in cellsToEval:
    #     echo "Col= " & $(i.coord.col) & "Row=" & $(i.coord.row) & " Score=" & $(i.score)
    
    # keep only the top scored cells.

    keepIf(cellsToEval, proc (cell: tuple[coord: CellCoord, score: int]): bool = return cell.score == topScore)

    # echo "filtered out: "
    # for i in cellsToEval:
    #     echo i.coord.col, i.coord.row, i.score
    
    # Choose a random one.
    let randIdx = rand(len(cellsToEval) - 1)
    let chosenRow = cellsToEval[randIdx].coord.row
    let chosenCol = cellsToEval[randIdx].coord.col
    # echo "choosen row: " & $(chosenRow) & " col: " & $(chosenCol)
    return (row: chosenRow, col: chosenCol)

#
# Draw the main menu screen
#
proc drawMainMenu(menuOpts: seq[string], currentOpt: int) =
    var colorSet  {.global.} = @[bgBlack, bgRed, bgGreen, bgYellow, bgBlue, bgMagenta, bgCyan]
    
    stdout.setCursorPos 0, 0
    stdout.styledWrite(colorSet[0],  "     ", colorSet[1], "     ", colorSet[2], "     ", colorSet[3], "     ", colorSet[4], "     ",  colorSet[5], "     ", colorSet[6], "     ")
    stdout.setCursorPos 0, 1
    stdout.styledWrite(colorSet[0],  "  R  ", colorSet[1], "  E  ", colorSet[2], "  V  ", colorSet[3], "  E  ", colorSet[4], "  R  ",  colorSet[5], "  S  ", colorSet[6], "  I  ")
    stdout.setCursorPos 0, 2
    stdout.styledWrite(colorSet[0],  "     ", colorSet[1], "     ", colorSet[2], "     ", colorSet[3], "     ", colorSet[4], "     ",  colorSet[5], "     ", colorSet[6], "     ")
    let first = colorSet[0]
    colorSet.delete(0, 0)
    colorSet.add(first)

    stdout.setCursorPos 0, 4
    stdout.styledWrite(bgBlue, fgCyan, styleBright, "Written by Hernan Di Pietro") 
    
    for i, menuEntry in menuOpts:
        stdout.setCursorPos 0, 6 + i
        if i == currentOpt:
            stdout.styledWrite(bgWhite, fgBlue, menuEntry)
        else:
            stdout.styledWrite(bgCyan, fgWhite, menuEntry)

proc onQuit() {.noconv.}=
    resetAttributes()
    showCursor()

#############################################################################
#
# Main loop
#
#############################################################################

hideCursor()
system.addQuitProc(onQuit)

setBackgroundColor(bgBlue)
eraseScreen

gameState = gsMainMenu
randomize()

var 
    thisThinkingTimeStart: float = 0.0
    turnThinkingTime: float = 0.0

while true:    
    case gameState:
        of gsMainMenu:
            #
            # In-Game Main Menu State
            #

            const menuOpts = @["    One player game    ", "    Two player game    ", "    CPU   vs   CPU     ", "         Exit          "]
            drawMainMenu(menuOpts, currentMenuOpt)

            while true:
                let ch = getch()
                case ch:
                of 'S','s':
                    currentMenuOpt = if currentMenuOpt == len(menuOpts) - 1: 0 else: currentMenuOpt + 1
                    break
                of 'W','w':
                    currentMenuOpt = if currentMenuOpt == 0: len(menuOpts) - 1 else: currentMenuOpt - 1
                    break
                of '\13':
                    case currentMenuOpt:
                    of 0, 1, 2:
                        setBackgroundColor(bgBlue)
                        eraseScreen()
                        initBoard()
                        playerKind = [if currentMenuOpt == 2: pkComputer else: pkHuman, if currentMenuOpt == 2 or currentMenuOpt == 0: pkComputer else: pkHuman]
                        gameState = gsTurn
                        break
                    of 3:
                        resetAttributes()
                        eraseScreen()
                        echo "BYE!"
                        quit(0)                   
                else:
                    discard
                    
        of gsTurn:
            #
            # In-game state
            #
           
            thisPlayerAvailMoves = scanBoard()
            if thisPlayerAvailMoves == 0:
                if lastPlayerAvailMoves == 0:
                    gameState = gsEndGame
                    continue
                else:
                    lastPlayerAvailMoves = thisPlayerAvailMoves
                    turn = otherPlayer(turn)

            drawInGameScreen()

            if playerKind[ord(turn)] == pkComputer:
                gameState = gsThinking
                turnThinkingTime = float(rand(CPU_THINKING_TIME_RANGE_MS.min .. CPU_THINKING_TIME_RANGE_MS.max))
                thisThinkingTimeStart = cpuTime() * 1000
            else:
                let ch = getch()
                case ch:
                    of 'w','W':
                        currentCursor.row = if currentCursor.row == 0: BOARD_HEIGHT-1 else: currentCursor.row - 1
                    of 's','S':
                        currentCursor.row = if currentCursor.row == BOARD_HEIGHT-1: 0 else: currentCursor.row + 1
                    of 'a', 'A':
                        currentCursor.col = if currentCursor.col == 0: BOARD_WIDTH-1 else: currentCursor.col - 1
                    of 'd', 'D':
                        currentCursor.col = if currentCursor.col == BOARD_WIDTH-1: 0 else: currentCursor.col + 1
                    of '\13':
                        if placeDisc(currentCursor.row, currentCursor.col):
                            turn = otherPlayer(turn)
                    of '\27':
                        setBackgroundColor(bgBlue)
                        eraseScreen()
                        gameState = gsMainMenu
                    else:
                        discard

        of gsThinking:

            if ( (cpuTime() * 1000) - thisThinkingTimeStart) > turnThinkingTime:
                let cpuTurn = evaluateCpuTurn()
                discard placeDisc(cpuTurn.row, cpuTurn.col)
                turn = otherPlayer(turn)
                gameState = gsTurn 

            drawInGameScreen()

        of gsEndGame:
            
            drawInGameScreen()

            let ch = getch()

            setBackgroundColor(bgBlue)
            eraseScreen()
            gameState = gsMainMenu

