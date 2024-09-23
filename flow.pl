#!/opt/homebrew/bin/perl     # for mac homebrew perl
#!/usr/bin/perl
#flow chart

use utf8;
use feature 'unicode_strings';
use Encode;
use Text::VisualWidth::PP;
use Getopt::Long;
use Class::Struct;
use Data::Dumper;

binmode STDIN,  ":utf8";
binmode STDOUT, ":utf8";

# syntax
#   use "///" prefix for read flow
#
# start
# /// * function
#
# sequence
# /// a = b
#
# function call
# /// [submodule]
#
# loop
# /// { cond > 0
#
# loop end
# /// }
#
# loop(do-while)
# /// {
#
# loop end
# /// } cond > 0
#
# branch
# /// |> cond1 == false
#
# /// a = 1
#  else
# /// >
# /// a = 2
#  end of branch
# /// >|
#

#
# end of function
# /// **

# 構文解析
$ParseLeadStr = "///";                                      # 抽出用の先頭文字列

#形状パラメータ
$FontFamily = "Osaka-Mono,monospace";                       # font
$FontWidth = 10;                                            # フォントの幅(半角)
$FontWidthJ = 20;                                           # フォントの幅(全角)
$FontHeight = 20;                                           # フォントの高さ
$FontSizeS = 8;                                             # font(small)
$SeqWidth = 150;                                            # ボックスの幅
$BoxPadding = 4;                                            # パディング（内側の隙間）
$SeqMargin = 8;                                             # シーケンス間のマージン
$DiaHeight = 32;                                            # 分岐（菱側の高さ）
$SideMargin = 40;                                           # 分岐間の横方向のマージン
$ArrowLength = 5;                                           # 矢印の長さ
$ArrowWidth = 2;                                            # 矢印の幅
$FuncPadding = 5;                                           # 関数の２重線の隙間
$PageMargin = 10;


#色
$ColorModule = "mediumslateblue";  # 関数呼び出し
$ColorLoop = "yellow";       # ループの分岐部
$ColorBranch = "orangered";  # 分岐
$ColorNode = "white";        # 開始・終了ノード
$ColorSeq = "white";         # 通常処理部

struct Node => {
    type => '$', x => '$', y => '$', mid_x => '$', width => '$', height => '$',
    text => '$', style => '$', blocks => '@', selectors => '@',
};

$While = 1;
$EndLoop =2;
$If = 3;
$Else = 4;
$EndIf = 5;
$Func = 6;
$Seq = 7;
$Begin = 8;
$End = 9;
$Eof = 10;
$Branch = 11;
$Loop = 12;
$DoWhile = 13;
$JumpIn = 14;
$JumpOut = 15;

$Debug = 0;

foreach $infile (@ARGV) {
    print  "flow chart input $infile \n";

    open FILE, '<:encoding(UTF-8)', $infile || die "Can't open to $infile";
    $Line = 0;     # 種別
    $Text = "";    # 中身
    $PreRead = undef; # 先読み行
    &Readline();
    while ($Line == $Begin) {
        # parse function block
        my ($begin) = &CreateSequence($Text, $Begin);
        $Outfile = $Text . ".svg";
        print  "create $Outfile\n";
        &Readline();
        my ($block) = &ParseBlock();
        if ($Line != $End) {
            die "syntax error $LineNum near $Line $Text in main\n";
        };
        &Readline();
        my ($end) = &CreateSequence("", $End);
        my (@work) = ( $begin, @$block, $end );
        $ref_block_all = \@work;
        $Debug && print Dumper($ref_block_all);

        # fix position
        my($width, $height) =
            &Position($PageMargin,$PageMargin,$ref_block_all);
        $width += $PageMargin*2;
        $height += $PageMargin*2;

        @block0 = @$ref_block_all;

        $Debug && print "---\n";
        $Debug && print Dumper(@block0);
        $Debug && print "---\n";

        # draw svg flow chart
        &DrawFlow($Outfile, $width, $height, $ref_block_all);
    }

    if ($Line != $Eof) {
        #$ref_block_all = &ParseBlock();
        die "syntax error $LineNum near $Line $Text in main\n";
    }

    close(FILE);
    print "complete\n";
}
exit 0;

sub ParseBlock {
    $Debug && print "ParseBlock\n";
    my (@block) = ();

    while ($Line == $Seq || $Line == $Func ||
           $Line == $If || $Line == $While ||
           $Line == $JumpOut || $Line == $JumpIn) {
        if ($Line == $Seq) {                               # 通常文
            my($seq) = &CreateSequence($Text);
            push(@block, $seq);
            &Readline();
        } elsif ($Line == $Func) {
            my($seq) = &CreateSequence($Text, $Func);
            push(@block, $seq);
            &Readline();
        } elsif ($Line == $JumpIn) {
            my($seq) = &CreateJumpIn($Text);
            push(@block, $seq);
            &Readline();
        } elsif ($Line == $JumpOut) {
            my($seq) = &CreateJumpOut($Text);
            push(@block, $seq);
            &Readline();
        } elsif ($Line eq $If) {
            my($seq) = &ParseIf();
            push(@block, $seq);
        } elsif ($Line == $While) {
            my($seq) = &ParseWhile();
            push(@block, $seq);
        }
    }
    return \@block;
}

sub ParseIf {
    $Debug && print "ParseIf $Text\n";
    my ($condition) = $Text;
    my @ref_blocks;
    my $ref_block;
    my @Selectors;

    push(@Selectors, $Selector);
    &Readline();
    $ref_block = &ParseBlock();
    push(@ref_blocks, $ref_block);
    while ($Line == $Else) {
        push(@Selectors, $Selector);
        &Readline();
        $ref_block = &ParseBlock();
        push(@ref_blocks, $ref_block);
    }
    if ($Line == $EndIf) {
        &Readline();
    } else {
        die "syntax error $LineNum near $Line $Text in if\n";
    }
    return &CreateBranch($condition, \@ref_blocks, \@Selectors);
}

sub ParseWhile {
    $Debug && print "ParseWhile $Text\n";
    my $condition = $Text;
    my $do_while = 0;

    &Readline();
    my ($ref_block) = &ParseBlock();
    if ($Line == $EndLoop) {
        if (!$condition) {
            $condition = $Text;
            $do_while = 1;
        }
        &Readline();
    } else {
        die "syntax error $LineNum near $Line $Text in loop\n";
    }
    return &CreateLoop($condition,$ref_block, $do_while);
}


sub CreateJumpIn {
    my ($text) = @_;
    my $seq = Node->new();

    $seq->type($JumpIn);
    $seq->x(0);
    $seq->y(0);
    $seq->mid_x($SeqWidth / 2);
    $seq->width($SeqWidth);
    $seq->height($FontHeight + $BoxPadding * 2  + $SeqMargin * 2);
    $seq->text($text);

    return $seq;                                           # 参照を返す
}

sub CreateJumpOut {
    my ($text) = @_;
    my $seq = Node->new();

    $seq->type($JumpOut);
    $seq->x(0);
    $seq->y(0);
    $seq->mid_x($SeqWidth / 2);
    $seq->width($SeqWidth);
    $seq->height($FontHeight + $BoxPadding * 2  + $SeqMargin * 2);
    $seq->text($text);

    return $seq;                                           # 参照を返す
}

#構造作成
sub CreateSequence {
    my ($text,$style) = @_;
    my $seq = Node->new();
    my $w = 0;
    my $h = 0;
    my ($ch, $l, $w_max);

    $w_max = $SeqWidth;

    foreach $l (split /\n/, $text) {
        foreach $ch (split //, $l) {
            if ($ch =~ /[\x20-\x7f]/) {
                $w += $FontWidth;
            } elsif ($ch =~ /\n/) {
                $h += $FontHeight;
            } else {
                $w += $FontWidthJ;
            }
        }
        if ($w_max < $w) {
            $w_max = $w;
        }
        $h += $FontHeight;
    }
    if ($h == 0) {
        $h = $FontHeight;
    }

    $seq->type($Seq);
    $seq->x(0);
    $seq->y(0);
    $seq->mid_x($w_max / 2);
    $seq->width($w_max);
    if ($style eq $Begin) {
        $seq->height($h + $BoxPadding * 2  + $SeqMargin);
    } elsif ($style eq $End) {
        $seq->height($h + $BoxPadding * 2);
    } else {
        $seq->height($h + $BoxPadding * 2  + $SeqMargin * 2);
    }
    $seq->text($text);
    $seq->style($style);
    return $seq;                                           # 参照を返す
}

sub CreateBranch {
    my ($text, $ref_blocks, $selectors) = @_;
    my (@ref_blocks) = @$ref_blocks;
    my @width, @height, @mid_x;
    my $i = 0;
    my $w = 0;
    my $h = 0;

    my $seq = Node->new();

    foreach $ref_block (@ref_blocks) {
        ($width[$i], $height[$i], $mid_x[$i]) = &SizeOfBlock($ref_block);
        $w += $width[$i];
        if ($h < $height[$i]) {
            $h = $height[$i];
        }
        $seq->blocks($i, $ref_block);
        $i ++;
    }
    $w += $SideMargin * ($i - 1);
    if ($i == 1) {
        $w += $SideMargin;
    }

    $seq->type($Branch);
    $seq->selectors($selectors);
    $seq->x(0);
    $seq->y(0);
    $seq->mid_x($mid_x[0]);
    $seq->width($w);
    $seq->height($h + $DiaHeight + $SeqMargin * 3);
    $seq->text($text);

    return $seq;                                           # 参照を返す
}

sub CreateLoop {
    my ($text, $ref_block, $do_while) = @_;
    my ($width, $height, $mid_x) = &SizeOfBlock($ref_block);
    my $seq = Node->new();

    $seq->x(0);
    $seq->y(0);
    $seq->text($text);
    $seq->blocks(0, $ref_block);

    if (!$do_while) {
        $seq->type($Loop);
        $seq->mid_x($mid_x + $SideMargin);
        $seq->width($width + $SideMargin * 2);
        $seq->height($height + $DiaHeight + $SeqMargin * 5);
    } else {
        $seq->type($DoWhile);
        $seq->mid_x($mid_x + $SideMargin);
        $seq->width($width + $SideMargin);
        $seq->height($height + $DiaHeight + $SeqMargin * 2);
    }

    return $seq;                                           # 参照を返す
}

# Size 大きさ(幅、高さ)と中心点のX座標を返す
sub SizeOfBlock {
    my ($ref_block) = @_;
    my ($width) = $SeqWidth;
    my ($height) = 0;
    my ($left) = $width / 2;
    my ($right) = $width / 2;
    my ($ref_seq);

    foreach $ref_seq (@$ref_block) {
        if ($left < $ref_seq->mid_x) {
            $left = $ref_seq->mid_x;
        }
        if ($right < $ref_seq->width - $ref_seq->mid_x) {
            $right = $ref_seq->width - $ref_seq->mid_x;
        }
        $height += $ref_seq->height;
    }
    $width = $left + $right;

    return ($width, $height, $left);
}

#位置を決定する
sub Position {
    my ($x0,$y0,$ref_block) = @_;
    my ($width, $height, $mid_x) = &SizeOfBlock($ref_block);
    my ($cur_y) = $y0;
    $Debug && print "Position $width, $height, $mid_x\n";

    foreach $ref_seq (@$ref_block) {
        $ref_seq->x($x0 + $mid_x - $ref_seq->mid_x);
        $ref_seq->y($cur_y);
        $cur_y += $ref_seq->height;
        if ($ref_seq->type == $Loop) {
            &Position($ref_seq->x + $SideMargin,
                      $ref_seq->y + $DiaHeight + $SeqMargin * 3,
                      $ref_seq->blocks(0));
        } elsif ($ref_seq->type == $DoWhile) {
            &Position($ref_seq->x + $SideMargin,
                      $ref_seq->y,
                      $ref_seq->blocks(0));
        } elsif ($ref_seq->type == $Branch) {
            my $offset_x = 0;
            my $ref_block;
            my $w1, $h1;

            my $count = 0;
            while ($ref_block  = $ref_seq->blocks($count++)) {
                ($w1, $h1) = &Position($ref_seq->x + $offset_x,
                                       $ref_seq->y + $DiaHeight +$SeqMargin * 2,
                                       $ref_block);           # ???
                $offset_x += $w1 + $SideMargin;
            }
        }
    }

    return ($width,$height);
}

# 1ライン読みだし
sub GetLine {
    if (defined($PreRead)) {
        my $l = $PreRead;
        $PreRead = undef;
        return $l;
    }
    if (eof(FILE)) {
        return "__EOF__";
    } else {
        my $l = <FILE>;
        $LineNum = $.;
        return $l;
    }
}

sub RevertLine {
    my $l = $_;
    $PreRead = $;
}

#字句解析部（行単位）
sub Readline {
    my($l, $org_l);
    my $Debug = 0;
    $Line = 0;
    $Text = "";
    $Selector = "";

    while (1) {
        $l = &GetLine();
        $org_l = $l;
        if ($l eq "__EOF__") {
            $Line = $Eof;
            $Debug && print "EOF:\n";
            return;
        }
        if ($l =~ /${ParseLeadStr}\s*(.*)/) {     # remove match ///
            $l = $1;
            $Debug && print "READ: '$l'\n";
        } else {
            if ($Line != 0) {
                $Debug && print "SEQUENCE1: $Line '$Text'\n";
                return;
            }
            next;
        }

        if ($l =~ /\{\s*(.*)\s*$/) {                   # { as loop
            if ($Line != 0) {
                goto END_SEQ;
            }
            $Line = $While;
            $Text = $1;
            $Debug && print "Loop($Line):$Text\n";
            return;
        } elsif ($l =~ /\}\s*(.*)\s*$/) {              # } as loop end
            if ($Line != 0) {
                goto END_SEQ;
            }
            $Line = $EndLoop;
            $Text = $1;
            $Debug && print "LoopEnd($Line):$Text\n";
            return;
        } elsif ($l =~ /=>\s*(.*)/) {                       # =>
            if ($Line != 0) {
                goto END_SEQ;
            }
            $Line = $JumpOut;
            $Text = $1;
            $Debug && print "JumpOut:$Text\n";
        } elsif ($l =~ /<=\s*(.*)/) {                       # <=
            if ($Line != 0) {
                goto END_SEQ;
            }
            $Line = $JumpIn;
            $Text = $1;
            $Debug && print "JumpIn:$Text\n";
            return;
            return;
        } elsif ($l =~ /\|>\s*([^\:]*)(\:(.*)|)\s*$/) { # |> as start branch
            if ($Line != 0) {
                goto END_SEQ;
            }
            $Line = $If;
            $Text = $1;
            $Selector = $3;
            $Debug && print "Branch($Line):$Text $Selector\n";
            return;
        } elsif ($l =~ />(\s+(.*)\s*|)$/) {           # > as branch internal
            if ($Line != 0) {
                goto END_SEQ;
            }
            $Line = $Else;
            $Text =  "";
            $Selector = $2;
            $Debug && print "BranchIn($Line): $Text $Selector\n";
            return;
        } elsif ($l =~ />\|$/) {                       # >| branch end
            if ($Line != 0) {
                goto END_SEQ;
            }
            $Line = $EndIf;
            $Debug && print "BranchEnd($Line)\n";
            return;
        } elsif ($l =~ /\[([^\]]*)\]$/) {              # [func]
            if ($Line != 0) {
                goto END_SEQ;
            }
            $Line = $Func;
            $Text = $1;
            $Debug && print "Module($Line):$Text\n";
            return;
        } elsif ($l =~ /\*\s+([^\s]*)/) {              # * name
            if ($Line != 0) {
                goto END_SEQ;
            }
            $Line = $Begin;
            $Text = $1;
            $Debug && print "Function($Line):'$Text'\n";
            return;
        } elsif ($l =~ /\*\*/) {                       # **
            if ($Line != 0) {
                goto END_SEQ;
            }
            $Line = $End;
            $Text = $1;
            $Debug && print "End($Line):$Text\n";
            return;
        } elsif ($l =~ /([^\s].*)$/) {                 # sequence
            if ($Line != $Seq) {
                $Line = $Seq;
                $Text = $1;
            } else {
                $Text .= "\n$1";
            }
        }
    }
    $Debug && print "Read($Line):$Text\n";
    return;
  END_SEQ:
    &RevertLine($org_l);
    $Debug && print "SEQUENCE: '$Text'\n";
    return;
}

##################################################################
#SVG
sub DrawFlow {
    my ($out_file, $width, $height, $ref_block) =@_;

    open(OUT, '>:encoding(UTF-8)', $out_file) || die "Can't open to $out_file\n"; # FILEを開く(utf8)

    &StartPage($width, $height);
    &DrawBlock($ref_block);
    &EndPage();
    close(OUT);
}

sub DrawBlock {
    my ($ref_block) = @_;
    foreach $ref_seq (@$ref_block) {
        my($type) = $ref_seq->type;
        if ($type == $Seq) {
            $Debug && &TestBox($ref_seq->x,$ref_seq->y,
                               $ref_seq->width,$ref_seq->height);
            &DrawSequence($ref_seq);
        } elsif ($type == $Branch) {
            $Debug && &TestBox($ref_seq->x,$ref_seq->y,
                               $ref_seq->width,$ref_seq->height);

            &DrawBranch($ref_seq);
            my $block;
            my $count = 0;
            while ($block  = $ref_seq->blocks($count++)) {
                &DrawBlock($block);                           # ???
            }
        } elsif ($type == $Loop) {
            $Debug && &TestBox($ref_seq->x,$ref_seq->y,
                               $ref_seq->width,$ref_seq->height);
            &DrawLoop($ref_seq);
            &DrawBlock($ref_seq->blocks(0));
        } elsif ($type == $DoWhile) {
            $Debug && &TestBox($ref_seq->x,$ref_seq->y,
                               $ref_seq->width,$ref_seq->height);
            &DrawDoWhile($ref_seq);
            &DrawBlock($ref_seq->blocks(0));
        } elsif ($type == $JumpIn) {
            $Debug && &TestBox($ref_seq->x,$ref_seq->y,
                               $ref_seq->width,$ref_seq->height);
            &DrawJumpIn($ref_seq);
        } elsif ($type == $JumpOut) {
            $Debug && &TestBox($ref_seq->x,$ref_seq->y,
                               $ref_seq->width,$ref_seq->height);
            &DrawJumpOut($ref_seq);
        }
    }
}

sub DrawLoop {
    my ($ref_seq) = @_;
    my ($x,$y,$mid_x,$width,$height) = ($ref_seq->x,$ref_seq->y,
                                        $ref_seq->mid_x,
                                        $ref_seq->width,$ref_seq->height);
    $Debug && print "DrawLoop $x, $y, $width, $height, $mid_x\n";

    my ($text) = sprintf("%16.16s", $ref_seq->text);

    my ($cx) = $x + $mid_x;
    my ($cy) = $y + $SeqMargin * 2 + $DiaHeight / 2;
    my ($ty) = $cy + $FontHeight / 2;
    my ($x_out) = $x + $width;
    my ($bottom_y) = $y + $height;

    &Polyline($cx,$y,$cx,$y + $DiaHeight + $SeqMargin * 3);
    &Diamond($cx, $y + $SeqMargin*2, $SeqWidth, $DiaHeight, $ColorLoop);
    &Text($cx,$ty, $text);
    &TextSmall($cx - $FontSizeS*2 ,$cy + $DiaHeight/2 + $FontSizeS, "YES");
    &TextSmall($cx + $SeqWidth/2 + $FontSizeS*2 ,$cy - 2, "NO");
    &Polyline($cx + $SeqWidth/2, $cy,
              $x_out, $cy,
              $x_out, $bottom_y - $SeqMargin,
              $cx, $bottom_y - $SeqMargin,
              $cx, $bottom_y);
    &PolylineA($cx, $bottom_y - $SeqMargin*2,
               $x, $bottom_y - $SeqMargin*2,
               $x, $y + $SeqMargin,
               $cx, $y + $SeqMargin);
}

sub DrawDoWhile {
    my ($ref_seq) = @_;
    my ($x,$y,$mid_x,$width,$height) = ($ref_seq->x,$ref_seq->y,
                                        $ref_seq->mid_x,
                                        $ref_seq->width,$ref_seq->height);
    $Debug && print "DrawDoWhile $x, $y, $width, $height, $mid_x\n";

    my ($text) = sprintf("%16.16s", $ref_seq->text);

    my ($cx) = $x + $mid_x;
    my ($cy) = $y + $height - $SeqMargin - $DiaHeight / 2;
    my ($ty) = $cy + $FontHeight / 2;
    my ($bottom_y) = $y + $height;

    &Polyline($cx,$cy - $DiaHeight / 2 - $SeqMargin, $cx, $bottom_y);
    &Diamond($cx, $cy - $DiaHeight / 2, $SeqWidth, $DiaHeight, $ColorLoop);
    &Text($cx,$ty, $text);
    &TextSmall($cx - $FontSizeS*2 ,$cy + $DiaHeight/2 + $FontSizeS, "NO");
    &TextSmall($cx - $SeqWidth/2 - $FontSizeS*3 ,$cy - 2, "YES");
    &PolylineA($cx - $SeqWidth/2 , $cy,
               $x, $cy,
               $x, $y,
               $cx, $y);
}

# branch loop width{0|1}の処理が必要
sub DrawBranch {
    my ($ref_seq) = @_;
    my ($x,$y,$mid_x,$width,$height) = ($ref_seq->x,$ref_seq->y,
                                        $ref_seq->mid_x,
                                        $ref_seq->width,$ref_seq->height);
    my ($text) = sprintf("%16.16s", $ref_seq->text);
    my $cx = $x + $mid_x;                                 # 中央ｘ位置
    my $cy = $y + $SeqMargin + $DiaHeight / 2;             # 分岐の中央Ｙ位置
    my $ty = $cy + $FontHeight / 2;                       # テキスト表示位置
    my $ref_block;
    my $last_x;
    my $Debug = 0;

    $Debug && print "--DrawBranch start\n";
    $Debug && print Dumper($ref_seq);
    $Debug && print "--DrawBranch end\n";

    &Polyline($cx, $y, $cx, $y + $SeqMargin);           # 矩形直上の線
    &Diamond($cx, $y + $SeqMargin, $SeqWidth, $DiaHeight, $ColorBranch); # 矩形
    &Text($cx,$ty, $text);
    &Polyline($cx, $cy + $DiaHeight/2,
              $cx, $cy + $DiaHeight/2 + $SeqMargin);       # 矩形直下の線

    my $use_yes_no = 1;
    my $count = 0;
    while ($ref_block = $ref_seq->blocks($count++)) {
        my ($bw, $bh, $bmid_x) = &SizeOfBlock($ref_block); # ???
        my $top = $$ref_block[0];
        my $y;

        $last_x = $top->x + $top->mid_x;
        if ($count > 1) {
            &Polyline($last_x, $cy,                        # 分岐直上の線
                      $last_x, $top->y);
            &Polyline($last_x, $top->y + $bh,              # 分岐直下の線
                      $last_x, $ref_seq->y + $ref_seq->height - $SeqMargin);
        } else {
            &Polyline($last_x, $top->y + $bh,
                      $last_x, $ref_seq->y + $ref_seq->height);  # 分岐の合流点の下の線
        }

        my $sel = $ref_seq->selectors($count - 1);
        if (defined($sel)) {
            $Debug && print "  selecor $sel\n";
            &TextSmall($last_x + 16, $top->y,              # 分岐直下の線
                       $sel);
            $use_yes_no = 0;
        }

    }
    $count --;

    if ($use_yes_no) {
        &TextSmall($cx - $FontSizeS*2 ,$cy + $DiaHeight/2 + $FontSizeS, "YES");
        &TextSmall($cx + $SeqWidth/2 + $FontSizeS*2 ,$cy - 2, "NO");
    }
    if ($count == 1) {
        &PolylineA($cx + $SeqWidth/2, $cy,
                   $x + $width, $cy,
                   $x + $width, $y + $height - $SeqMargin,
                   $cx, $y + $height - $SeqMargin);
    } else {
        &Polyline($cx + $SeqWidth/2, $cy,
                  $last_x, $cy);
        &PolylineA($last_x, $y + $height - $SeqMargin,
                   $cx , $y + $height - $SeqMargin);
    }
}


sub DrawJumpIn {
    my ($ref_seq) = @_;
    my ($x, $y, $width, $height, $mid_x, $text) =
        ($ref_seq->x, $ref_seq->y,
         $ref_seq->width, $ref_seq->height,
         $ref_seq->mid_x, $ref_seq->text);

    my ($cx) = $x + $mid_x;
    my ($cy) = $y + $height / 2;

    my $t;

    $Debug && print "DrawJumpIn $x, $y, $width, $height, $mid_x, $text\n";
    &Polyline($cx, $y, $cx, $y + $height);
    &PolylineA($cx + $SeqWidth / 4, $cy, $cx, $cy);
    &Circle($cx + $SeqWidth / 4 + 15, $cy, 15)
    &Text($cx + $SeqWidth / 4 + 15, $cy + $FontHeight / 2, $text);

    #&RoundBox($x, $y, $width, $FontHeight * 1 + $BoxPadding * 2);
}

sub DrawJumpOut {
    my ($ref_seq) = @_;
    my ($x, $y, $width, $height, $mid_x, $text) =
        ($ref_seq->x, $ref_seq->y,
         $ref_seq->width, $ref_seq->height,
         $ref_seq->mid_x, $ref_seq->text);

    my ($cx) = $x + $mid_x;
    my ($cy) = $y + $height / 2;

    my $t;

    $Debug && print "DrawJumpOut $x, $y, $width, $height, $mid_x, $text\n";
    &Polyline($cx, $y, $cx, $cy);
    &PolylineA($cx, $cy, $cx + $SeqWidth / 4, $cy);
    &Circle($cx + $SeqWidth / 4 + 15, $cy, 15)
    &Text($cx + $SeqWidth / 4 + 15, $cy + $FontHeight / 2, $text);

    #&RoundBox($x, $y, $width, $FontHeight * 1 + $BoxPadding * 2);
}

sub DrawSequence {
    my ($ref_seq) = @_;
    my ($x, $y, $width, $height, $mid_x, $text, $style) =
        ($ref_seq->x, $ref_seq->y,
         $ref_seq->width, $ref_seq->height,
         $ref_seq->mid_x, $ref_seq->text,
         $ref_seq->style);
    my ($cx) = $x + $mid_x;
    my $t;

    $Debug && print "DrawSequence $x, $y, $width, $height, $mid_x, $text, $style\n";
    if ($style eq $Begin) {
        &Polyline($cx, $y + $height - $SeqMargin, $cx, $y + $height);
        &RoundBox($x, $y, $width, $FontHeight * 1 + $BoxPadding * 2);

    } elsif ($style == $End) {
        &Polyline($cx, $y, $cx, $y + $SeqMargin);
        $y += $SeqMargin;
        &RoundBox($x, $y, $width, $FontHeight * 1 + $BoxPadding * 2);
        $text = "END";
    } else {
        &Polyline($cx, $y, $cx, $y + $height);
        $y += $SeqMargin;
        if ($style == $Func) {
            &BoxF($x, $y, $width, $height - $SeqMargin * 2);
        } else {
            &Box($x, $y, $width, $height - $SeqMargin * 2);
        }
    }
    foreach $t (split /\n/, $text) {
        &Text($cx, $y + $FontHeight * 1 + $BoxPadding, $t);
        $y += $FontHeight;
    }
}

#Pageの始め
sub StartPage {
    my ($width, $height) = @_;
	print OUT <<END_OF_DATA;
<?xml version="1.0" standalone="no"?>
<svg width="$width" height="$height" version="1.1" xmlns="http://www.w3.org/2000/svg">
  <g transform="scale(1.0)">
END_OF_DATA
}

#Pageの終わり
sub EndPage {
	print OUT <<END_OF_DATA;
  </g>
</svg>
END_OF_DATA
}

#描画プリミティブ
#ボックス（処理内容）
sub Box {
    my($x,$y,$w,$h) = @_;
	print OUT <<END_OF_DATA;
        <rect x="$x" y="$y" width="$w" height="$h" fill="$ColorSeq" stroke="black" />
END_OF_DATA
}

#ボックス（関数呼び出し）
sub BoxF {
    my($x,$y,$w,$h) = @_;
    my($x1,$w1) = ($x + $FuncPadding,$w - $FuncPadding*2);
	print OUT <<END_OF_DATA;
        <rect x="$x" y="$y" width="$w" height="$h" fill="$ColorModule" stroke="black" />
        <rect x="$x1" y="$y" width="$w1" height="$h" fill="$ColorModule" stroke="black" />
END_OF_DATA
}

#角丸のボックス（開始・終了ノード）
sub RoundBox {
    my($x,$y,$w,$h) = @_;
    my ($r) = $h/2;
	print OUT <<END_OF_DATA;
        <rect x="$x" y="$y" width="$w" height="$h" rx="$r" fill="$ColorNode" stroke="black" />
END_OF_DATA
}

#文字列表示（通常サイズ）
sub Text {
    my ($x, $y, $text) = @_;
    my ($text2) = &XMLText($text);
	print OUT <<END_OF_DATA;
        <text text-anchor="middle" dominant-baseline="text-after-edge" x="$x" y="$y" font-size="$FontHeight" font-family="$FontFamily" >
            $text2
        </text>
END_OF_DATA
}

#文字列表示（小サイズ）＝分岐先
sub TextSmall {
    my ($x, $y, $text) = @_;
    my ($text2) = &XMLText($text);
	print OUT <<END_OF_DATA;
        <text text-anchor="middle" x="$x" y="$y" font-size="$FontSizeS" font-family="$FontFamily">
            $text2
        </text>
END_OF_DATA
}

#ライン
sub Polyline {
    my(@lines) = @_;
    my ($x,$y);
    $x = shift(@lines);
    $y = shift(@lines);
    my ($points) = "$x $y";
    while (@lines) {
        $x = shift(@lines);
        $y = shift(@lines);
        $points = $points . ", $x $y";
    }
	print OUT <<END_OF_DATA;
    <polyline points="$points" fill="none" stroke="black" />
END_OF_DATA
}

#ライン（矢印付き）
sub PolylineA {
    my(@lines) = @_;
    my ($x,$y,$x2,$y2,$x3,$y3);
    my($num) = $#lines;
    my ($dx) = $lines[$num-1] - $lines[$num-3];
    my ($dy) = $lines[$num] - $lines[$num-2];
    if (abs($dx) > abs($dy)) {
        $x2 = ($dx > 0) ? $lines[$num-1] - $ArrowLength : $lines[$num-1] + $ArrowLength;
        $y2 = $lines[$num] + $ArrowWidth;
        $x3 = $x2;
        $y3 = $lines[$num] - $ArrowWidth;
    } else {
        $x2 = $lines[$num-1] + $ArrowWidth;
        $y2 = ($dy > 0) ? $lines[$num] - $ArrowLength : $lines[$num-1] + $ArrowLength;
        $x3 = $lines[$num-1] - $ArrowWidth;
        $y3 = $y2;
    }

    $x = shift(@lines);
    $y = shift(@lines);
    my ($points) = "$x $y";
    while (@lines) {
        $x = shift(@lines);
        $y = shift(@lines);
        $points = $points . ", $x $y";
    }

	print OUT <<END_OF_DATA;
    <polyline points="$points" fill="none" stroke="black" />
    <polygon points="$x $y, $x2, $y2, $x3 $y3" fill="black" stroke="black" />
END_OF_DATA
}

sub PolylineDebug {
    my(@lines) = @_;
    my ($x,$y);
    $x = shift(@lines);
    $y = shift(@lines);
    my ($points) = "$x $y";
    while (@lines) {
        $x = shift(@lines);
        $y = shift(@lines);
        $points = $points . ", $x $y";
    }
	print OUT <<END_OF_DATA;
    <polyline points="$points" fill="none" stroke="red" />
END_OF_DATA
	print <<END_OF_DATA;
debug: <polyline points="$points" fill="none" stroke="red" />
END_OF_DATA
}

#テスト用ＢＯＸ
sub TestBox {
    my($x, $y, $width, $height) = @_;
	print OUT <<END_OF_DATA;
    <rect x="$x" y="$y" width="$width" height="$height" fill="none" stroke="red"/>
END_OF_DATA
}

#XMLの特殊文字変換
sub XMLText {
    local($text) =@_;
    $text =~ s/\&/\&amp\;/g; # '&' → '&amp'
    $text =~ s/\</\&lt\;/g; # '<' → '&lt'
    $text =~ s/\>/\&gt\;/g; # '>' → '&gt'
    return ($text);
}


sub Diamond {
    my($cx,$y,$w,$h,$c) = @_;                                  # 始点は中央上
    my($x2,$y2,$x3,$y3) = ($cx + $w/2, $y + $h/2, $cx - $w/2, $y + $h);
    print OUT <<END_OF_DATA;
    <polygon points="$cx $y, $x2 $y2, $cx $y3, $x3 $y2" fill="$c" stroke="black" />
END_OF_DATA
}

sub Circle {
    my($x,$y,$r) = @_;                                  # 始点は中央上
    print OUT <<END_OF_DATA;
    <circle cx="$x" cy="$y" r="$r" stroke="black" fill="none" />
END_OF_DATA
}
