# NimReversi

A console-based Reversi game written in Nim. Just for fun.

![mainscr](https://user-images.githubusercontent.com/4740613/58450611-08cd0c80-80e6-11e9-973b-2ea5e83f8ce6.png)
![game](https://user-images.githubusercontent.com/4740613/58450616-0bc7fd00-80e6-11e9-82e7-30e5da26f072.png)

## Requeriments

Just compile with Nim compiler C backend. Any version >0.19.0 should work. Also, portability between common platforms shall not pose any problem.

```
nim c reversi.nim
```

* Use `--cc:vcc` to compile using Microsoft compilers. 
* Use `-d:release` to generate an optimized build.

## How to play

There are three modes available: One Player (vs CPU), Two Players and CPU vs CPU. 
Control cursor with A W S D keys, and press ENTER to place discs.

## Details

The computer AI will filter all but the best positions, that is, where the maximum number of rival discs can be overthrown/reversed. Subsequently, it will randomly select one of the top-scored cells. The "THINKING" animated label just simulates a deep AI.  Actually, it's completely dumb. But Reversi is known for being a hard game in terms of planning , even this dumb AI can be challenging.  According to Wikipedia, 

>> This is mostly due to difficulties in human look-ahead peculiar to Othello: The interchangeability of the disks and therefore apparent strategic meaninglessness (as opposed to chess pieces for example) makes an evaluation of different moves much harder.

## License

Copyright (c) 2019 Hernán Di Pietro

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
