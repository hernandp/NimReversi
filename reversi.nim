import terminal, random, strscans, sequtils

type 
    GameState = enum
        gsMainMenu, gsTurn, gsEndGame

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

var
    gameState:      GameState
    running:        bool
    turn:           Player
    board:          array[0..(BOARD_WIDTH*BOARD_HEIGHT)-1, BoardCell]
    playerKind:     array[0..1, PlayerKind]
    scoreBoard:     tuple[black: int, white: int]
    currentMenuOpt: int = 0
    currentCursor:  CellCoord

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

    scoreBoard = (black: 0, white: 0)

#
# Print the current board, along scores
#
proc drawInGameScreen() =
    
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
            if currentCursor.row == thisRow and currentCursor.col == thisCol:
                backColor = bgRed
            else:
                backColor = if (idx + oddRow) mod 2 == 0: bgMagenta else: bgCyan

            stdout.styledWrite(backColor, 
                if getCellContent(thisRow, thisCol) == bcWhite: fgWhite else: fgBlack,
                if getCellContent(thisRow, thisCol) == bcEmpty: "   " else: " O ")

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
# opponent pieces for each empty cell.  Returns:
# A tuple with: 
# - the the total number of available overthrows in board for 
#   the current player. If 0 no moves are available.
# - score (count) of white discs.
# - score (count) of black discs.
#
proc scanBoard() : tuple[ totalMoveCount: int, blackScore: int, whiteScore: int ]=
    var 
        cellsToReverse: seq[CellCoord]
        retval : tuple[ totalMoveCount: int, blackScore: int, whiteScore: int ]

    retval.totalMoveCount = 0
    for thisCol in 0..BOARD_WIDTH - 1:
        for thisRow in 0..BOARD_HEIGHT - 1:
            if getCellContent(thisRow, thisCol) == bcEmpty:
                cellsToReverse = scanDiscsToReverse(thisRow, thisCol)
                board[getIndexFromCoord(thisRow, thisCol)].reverseCells = cellsToReverse
                retval.totalMoveCount += len(cellsToReverse)
            else:
                if getCellContent(thisRow, thisCol) == bcWhite:
                    retval.whiteScore += 1
                else:
                    retval.blackScore += 1
    return retval

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
    
    echo "found alternatives: "
    for i in cellsToEval:
        echo "Col= " & $(i.coord.col) & "Row=" & $(i.coord.row) & " Score=" & $(i.score)
    
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
# End of game routine
#
proc endGame(whiteScore: int, blackScore: int) =
    if whiteScore == blackScore:
        echo "DRAW"
    elif whiteScore > blackScore:
        echo "WHITE WINS"
    else:
        echo "BLACK WINS"    

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

#
# Main loop
#
system.addQuitProc(resetAttributes)

setBackgroundColor(bgBlue)
eraseScreen

gameState = gsMainMenu
randomize()

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
                        playerKind = [if currentMenuOpt == 2: pkComputer else: pkHuman, if currentMenuOpt == 2: pkComputer else: pkHuman]
                        gameState = gsTurn
                    of 3:
                        resetAttributes()
                        eraseScreen()
                        echo "BYE!"
                        quit(0)
                    else:
                        discard
                else:
                    discard
                    
        of gsTurn:
            #
            # In-game state
            #
            drawInGameScreen()

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
                    discard placeDisc(currentCursor.row, currentCursor.col)
                else:
                    discard

        of gsEndGame:
            echo "Y"
#[
turn = Player(rand(1))
while running:
    var 
        playerInput: string
        inRow, inCol: int
        lastPlayerAvailMoves: int
        thisPlayerAvailMoves: int
        whiteScore: int
        blackScore: int
    
    thisPlayerAvailMoves = scanBoard().totalMoveCount
    if thisPlayerAvailMoves == 0:
        if lastPlayerAvailMoves == 0:
            endGame(whiteScore, blackScore)
            break
        else:
            lastPlayerAvailMoves = thisPlayerAvailMoves
            echo "** No moves for current turn! **"
            turn = otherPlayer(turn)
            continue
            
        
    drawInGameScreen()

    echo "AvailMoveCount: " & $(thisPlayerAvailMoves)
    echo "BLACK: " & $(blackScore) & "WHITE: " & $(whiteScore)

    echo "TURN: ", turn

    if turn == plBlack and vsCpu:
        let cpuCell = evaluateCpuTurn()
        discard placeDisc(cpuCell.row, cpuCell.col)
        turn = plWhite
    else:        
        while true:    
            echo "Where to place your disc?  Enter ROW (0-7),COL(0-7): "
            if stdin.readLine(playerInput):
                if scanf(playerInput, "$i,$i", inRow, inCol):
                    if inRow < 0 or inRow > 7:
                        echo "Bad ROW input!"
                        continue
                    if inCol < 0 or inCol > 7:
                        echo "Bad COL input!"
                        continue
                    break
            
        if not placeDisc(inRow, inCol):
            echo ""
            echo "** Invalid move, select another position! ** "
            echo ""
        else:
            turn = otherPlayer(turn)



]#