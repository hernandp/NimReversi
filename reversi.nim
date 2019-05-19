import terminal, random, strscans, sequtils

type 
    BoardCellContent = enum
        bcWhite = "O", bcBlack = "X", bcEmpty = "."

    Player = enum
        plWhite = "White", plBlack = "Black"

    CellCoord = tuple[row: int, col: int]

    BoardCell = object
        content: BoardCellContent
        reverseCells: seq[CellCoord]

const
    BOARD_WIDTH = 8
    BOARD_HEIGHT = 8

var
    running: bool
    turn: Player
    board: array[0..(BOARD_WIDTH*BOARD_HEIGHT)-1, BoardCell]
    vsCpu: bool

proc setCellContent(row: int, col: int, what: BoardCellContent) =
    board[row * BOARD_WIDTH + col].content = what
    if what != bcEmpty:
        board[row * BOARD_WIDTH + col].reverseCells = @[]

proc getCellContent(row: int, col: int) : BoardCellContent =
    return board[row * BOARD_WIDTH + col].content

proc otherPlayer(p: Player) : Player =
    result = if p == plWhite: plBlack else: plWhite

proc isPlayerCell(p: Player, row: int, col: int) : bool =
    result = ord(getCellContent(row, col)) == ord(p)

proc cellInBoard(row: int, col: int) : bool = 
    result = row >= 0 and row < 8 and col >= 0 and col < 8
    
proc initBoard() =
    for i in 0..board.len-1:
        board[i].content = bcEmpty
    
    setCellContent(3, 3, bcWhite)
    setCellContent(3, 4, bcBlack)
    setCellContent(4, 3, bcBlack)
    setCellContent(4, 4, bcWhite)

proc printBoard() =
    echo "   0  1  2  3  4  5  6  7"
    for x in 0..BOARD_WIDTH - 1:
        stdout.write ($(x) & "  ")
        for y in 0..BOARD_HEIGHT - 1:
            let revCells = board[x * BOARD_WIDTH + y].reverseCells
            if (len(revCells) > 0):
                stdout.write($(len(revCells)) & "  ")
            else:
                stdout.write($(board[x*BOARD_WIDTH + y]).content & "  ")
        stdout.writeLine("")

proc flipCell(row: int, col: int) =
    setCellContent(row, col, if getCellContent(row,col) == bcWhite: bcBlack else: bcWhite)

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

proc placeDisc(row: int, col: int) : bool =
    if getCellContent(row, col) != bcEmpty:
        echo "Cell not empty!"
        return false
    
    let cellsToReverse = board[row * BOARD_WIDTH + col].reverseCells  
    
    # echo "DEBUG: " & $(cellsToReverse.len()) & " at r=" & $(row) & " c=" & $(col)
     
    if len(cellsToReverse) > 0:
        setCellContent(row, col, BoardCellContent(ord(turn)))
        for cell in cellsToReverse:
            flipCell(cell.row, cell.col)
        return true
    
    return false

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
    for x in 0..BOARD_WIDTH - 1:
        for y in 0..BOARD_HEIGHT - 1:
            if board[x * BOARD_WIDTH + y].content == bcEmpty:
                cellsToReverse = scanDiscsToReverse(x, y)
                board[x * BOARD_WIDTH + y].reverseCells = cellsToReverse
                retval.totalMoveCount += len(cellsToReverse)
            else:
                if board[x * BOARD_WIDTH + y].content == bcWhite:
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
    for col in 0..BOARD_WIDTH - 1:
        for row in 0..BOARD_HEIGHT - 1:
            let cell = board[row * BOARD_WIDTH + col]
            let cellScore = len(cell.reverseCells)
            if cellScore > 0 and cellScore >= topScore:
                cellsToEval.insert( (coord: (row: row, col: col), score: cellScore), 0)
                topScore = cellScore
    
    echo "found alternatives: "
    for i in cellsToEval:
        echo i.coord.col, i.coord.row, i.score
    
    # keep only the top scored cells.

    keepIf(cellsToEval, proc (cell: tuple[coord: CellCoord, score: int]): bool = return cell.score == topScore)

    echo "filtered out: "
    for i in cellsToEval:
        echo i.coord.col, i.coord.row, i.score
    
    # Choose a random one.
    let randIdx = rand(len(cellsToEval) - 1)
    return (row: cellsToEval[randIdx].coord.row, col: cellsToEval[randIdx].coord.col)

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

randomize()
initBoard()

running = true
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
        
    printBoard()

    echo "TURN: ", turn

    if turn == plBlack and vsCpu:
        let cpuCell = evaluateCpuTurn()
        discard placeDisc(cpuCell.row, cpuCell.col)
        break

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


            




