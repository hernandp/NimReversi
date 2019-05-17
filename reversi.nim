import terminal, random, strscans

type 
    BoardCell = enum
        bcWhite = "O", bcBlack = "X", bcEmpty = "."

    Player = enum
        plWhite = "White", plBlack = "Black"

const
    BOARD_WIDTH = 8
    BOARD_HEIGHT = 8

var
    running: bool
    turn: Player
    board: array[0..(BOARD_WIDTH*BOARD_HEIGHT)-1, BoardCell]

proc setCell(row: int, col: int, what: BoardCell) =
    board[row * BOARD_WIDTH + col] = what

proc getCell(row: int, col: int) : BoardCell =
    return board[row * BOARD_WIDTH + col]

proc otherPlayer(p: Player) : Player =
    result = if p == plWhite: plBlack else: plWhite

proc isPlayerCell(p: Player, row: int, col: int) : bool =
    result = ord(getCell(row, col)) == ord(p)

proc cellInBoard(row: int, col: int) : bool = 
    result = row >= 0 and row < 8 and col >= 0 and col < 8
    
proc initBoard() =
    for i in 0..board.len-1:
        board[i] = bcEmpty
    
    setCell(3, 3, bcWhite)
    setCell(3, 4, bcBlack)
    setCell(4, 3, bcBlack)
    setCell(4, 4, bcWhite)

proc printBoard() =
    echo "   0  1  2  3  4  5  6  7"
    for x in 0..BOARD_WIDTH - 1:
        stdout.write ($(x) & "  ")
        for y in 0..BOARD_HEIGHT - 1:
            stdout.write($(board[x*BOARD_WIDTH + y]) & "  ")
        stdout.writeLine("")


# Scan in the eight directions (UL, U, UR, R, DR, D, DL, L) for
# a line of rival discs bounded by our own that can be reversed. 
# dx = delta-X to add for next lookup
# dy = delta-Y to add for next lookup
proc lookupDiscsToReverse(turn: Player, row: int, col: int, dx: int, dy: int, cellsToReverse: var seq[tuple[row:int, col:int]]) : bool =
    if getCell(row, col) == bcEmpty or not cellInBoard(row, col):
        return false

    if not isPlayerCell(turn, row, col):
        if lookupDiscsToReverse(turn, row + dy, col + dx, dx, dy, cellsToReverse):
            cellsToReverse.add((row,col))

    return true
    

proc placeDisc(turn: Player, row: int, col: int) : bool =
    if getCell(row, col) != bcEmpty:
        echo "Cell not empty!"
        return false

    var cellsToReverse: seq[tuple[row: int, col: int]]
    let lookupResult = lookupDiscsToReverse(turn, row + 1, col + 1, 1, 1, cellsToReverse)
    return (lookupResult or (lookupResult and len(cellsToReverse) == 0))
        
randomize()
initBoard()

running = true
turn = Player(rand(1))
while running:
    var 
        playerInput: string
        inRow, inCol: int

    printBoard()
    echo "TURN: ", turn

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
        
    if not placeDisc(turn, inRow, inCol):
        echo "Invalid move, select another position!"


            




