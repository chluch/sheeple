#!/usr/bin/perl -w
use strict;

my @input;
my $inline = '(do|done|then|else|fi)';
my $bash_header = '#!/bin/dash';

sub uniq {
    my @arr = @_;
    my @uniq;
    my %seen;
    for my $element (@arr) {
        if (! $seen{$element}) {
            push @uniq, $element;
            $seen{$element} = 1;
        }
    }
    return @uniq;
}

sub lines {
    my $str = shift @_;
    my @arr = ();
    while ($str =~ /(;|&&|\|\|)\s*.+/) {
        # print "### STR $str ####\n";
        my $symbol = $1;
        my $line1 ='';
        my $line2 = '';
        if ($symbol =~ /\|\|/) {
            ($line1, $line2) = split(/\|\| /, $str, 2);
        }
        else {
            ($line1, $line2) = split(/$symbol /, $str, 2);
        }
        # print "### 1: $line1\n";
        # print "### 2: $line2 \n";
        push @arr, $line1;
        if ($symbol =~ /(&&|\|\|)/) {
            $symbol =~ s/ //g;
            push @arr, $symbol;
        }
        $str = $line2;
    }
    push @arr, $str;
    return @arr;
}

### PROCESS INPUT ###
while (my $line = <>) {
    chomp $line;
    next if (($line =~ /^\s*$/) or ($line =~ /^\s*$bash_header\s*$/));

    # handle inlines
    if (($line =~ /(;|&&|\|\|)\s*.+/) and ($line !~ />\/dev\//)) {
        my @temp = lines($line);
        for my $i (@temp) {
            if ($i =~ /$inline\s(.*)/) {
                my($first, $rest) = split(/\s/, $i, 2);
                push @input, $first, $rest;
            }
            else {
                push @input, $i;
            }
        }
    }

    # push if no inline
    else {
        push @input, $line;
    }
}

### A BUNCH OF SUBS ###
sub args {
    my $str = shift @_;

    # $0 or literal
    return $str if (($str =~ /\$0/) or ($str =~ /echo\s'.*\$(\d+|\*|@).*'/));

    # "$@"
    if ($str =~ /"\$@"/) {
        $str =~ s/"\$@"/\@ARGV/g;
        return $str;
    }

    # "$*"
    if ($str =~ /"\$\*"/) {
        $str =~ s/"\$\*"/"\@ARGV"/g;
        return $str;
    }

    # $* or $@
    if ($str =~ /(\$\*|\$@)/) {
        $str =~ s/(\$\*|\$@)/split ' ', (join ' ', \@ARGV)/g;
        return $str;
    } 

    # $# ... integer
    if ($str =~ /\$#(.*)(\d+)/) {
        my $exp = $1;
        my $num = $2;
        $str =~ s/\$#(.*)(\d+)/'$#ARGV'.$exp.($num-1)/ge;    
        return $str;
    }

    # $1 $2 ...
    $str =~ s/\$(\d+)/'$ARGV'.'['.($1-1).']'/ge;
    return $str;
}

sub cd {
    my $str = shift @_;
    if (($str =~ /cd (.*)/) and ($str !~ /[\'\"]cd[\'\"] (.*)/)) {
        return 'chdir '.'\''.$1.'\'';
    }
    return $str;
}

sub echo {
    my $str = shift @_;
    return $str if (($str !~ /echo/) or ($str =~ /[^'"]+\|[^'"]+/)); # can echo '|' but exclude pipelines
    my $to_echo;
    my $ret;
    my $newline = 1; # flag for echo -n
    my $start = '';

    if ($str =~ /^\s*echo\s*(.+)/) {
        $to_echo = $1;
    }
    elsif ($str =~ /(.+)\s*echo\s*(.+)/) {
        $start = $1;
        $to_echo = $2;
    }

    # -n flag
    if ($to_echo =~ /^\s*\-n/) {
        $newline = 0;
        $to_echo =~ s/^\s*\-n\s*//;
        $ret = 'print '.$to_echo
    }
    elsif (($to_echo !~ /^'.*'$|^".*"$/) and ($to_echo !~ /^glob/)) {
        my @temp = split ' ', $to_echo;
        for my $word (@temp) {
            $word =~ s/^\s*["']//;
            $word =~ s/["']\s*$//;
            $word =~ s/\"/\\\"/g;   # escape "
        }
        my $to_echo = join ' ', @temp;
        $ret = 'print '.'"'.$to_echo.'"';
    }
    else {
        $ret = 'print '.$to_echo;
    }

    if ($start ne '') {
        $ret = $start.$ret;
    }

    return $ret  if ($newline == 0);
    return $ret.', "\n"';
}

sub expr {
    my $str = shift @_;
    my $ret = $str;
    if ($str =~ /^\.*expr\s(.*)/) {
        $ret = 'print '.$1.', "\n";';
    }
    elsif ($str =~ /(.*)(\$\(|\`)expr\s(.+)(\)|\`)(.*)/) {
        my $str_before_expr = $1;
        my $value = $3.$5;
        $ret = $str_before_expr.$value;
    }
    elsif ($str =~ /(.*)\$\(\((.+)\)\)(.*)/) {
        my $start = $1;
        my $val = $2;
        my $end = $3;
        $val =~ s/([A-Za-z\-\_]+)/\$$1/g if (($val =~ /[A-Za-z\-\_]+/) and ($str !~ /=/));
        $ret = $start.$val.$end;
        $ret =~ s/\$\(\(//;
        $ret =~ s/\)\)//;
    }
    if ($ret =~ /\\\*/) {           # replace escaped multiplication operator \* in shell
        $ret =~ s/\\\*/\*/g;
    }
    return $ret;
}

sub file_matching {
    my $str = shift @_;
    if (($str =~ /[^\$]([^\$\s]*(\*|\?+|\[\w+\])[^\s]*)/) and ($str !~ /expr/)) {
        my $to_glob = $1;
        my $result = glob("$to_glob");
        return $str if (! $result); # do not process line if there is actually no file to glob!
        $str =~ s/([^\$\s]*(\*|\?+|\[\w+\])[^\s]*)/glob("$to_glob")/g;
    }
    return $str;
}

sub for_loop {
    my $str = shift @_;
    my $ret;

    # for ... in
    if ($str =~ /\s*for (.*) in ([^\*]+.*)/) {
        my $var = $1;
        my @iter = (split ' ', $2);
        foreach my $word (@iter) {
            if (($word !~ /["']+.*["']+/) and ($word !~ /[\$\@]{1}.*/)) {
                $word = '\''.$word.'\'';
            }
        }
        my $iterables = join ', ', @iter;
        return 'for '.'$'.$var.' ('.$iterables.') {'
    }

    # do
    elsif ($str =~ /\s*do\s*$/) {
        return '';
    }

    # done
    elsif ($str =~ /\s*done\s*$/) {
        return '}';
    }

    else {
        return $str;
    }
}

sub fx {
    my ($str, @arr) = @_;
    my $ret;
    if ($str =~ /^\s*(\w+)\(\)\s*\{/) {
        my $sub_name = $1;
        push @arr, $sub_name;
        $ret = 'sub '.$sub_name.' {';
    }
    # Warning: Only works for var declaration, simple things like x=y, n=1
    #  Does NOT work if expr involved!!! 
    elsif (($str =~ /^\s*local\s(.+)/) and ($str !~ /^\s*print/)) {
        my $locals = $1;
        if ($locals =~ /(.+)(\=\w+)/) {
            my $first = $1;
            my $rest = $2;
            $first =~ s/([a-zA-Z\-_]+)/\$$1/g;
            $rest =~ s/([a-zA-Z\-_]+)/ \$$1/g;
            $ret = 'my '.$first.' '.$rest;
        }
        else {
            $locals =~ s/([a-zA-Z\-_]+)/\$$1/g;
            $locals = join ', ', (split ' ', $locals);
            $ret = 'my ('.$locals.')';
        }
    }
    elsif (($str =~ /^\s*return/) and ($str !~ /^\s*print/)) {
        $ret = $str.';';
    }
    return ($ret, @arr) if ($ret);
    return ($str, @arr);
}

sub if_while {
    my $str = shift @_;
    my $ifs = 'if|elif|while';
    if ($str =~ /^\s*($ifs)\s(.+)/) {
        my $ifs = $1;
        my $condition = $2;
        if ($ifs eq 'elif') {
            $ifs = '} elsif';
        }
        return $ifs.' ('.$condition.') {' if ($condition !~ /^\s*\(/);
        return $ifs.' '.$condition.' {'
    }
    elsif ($str =~ /^\s*then\s*$/) {
        return '';
    }
    elsif ($str =~ /^\s*else\s*$/) {
        return '} else {';
    }
    elsif ($str =~ /^\s*fi\s*$/) {
        return '}'
    }
    return $str;
}

sub reading {
    my $str = shift @_;
    my $chomp;
    if ($str =~ /^\s*read (.*)/) {
        $chomp = 'chomp '.'$'.$1;
        my $ret = '$'.$1.' = '.'<STDIN>;';
        return join "\n", $ret, $chomp;
    }
    return $str;
}

sub semicolon {
    my @arg = @_;
    my @arr;
    for (my $i=0; $i<@arg; $i++) {
        next if ($arg[$i] =~ /^\s*$/);
        if (($arg[$i] =~ /^(.+)(#\s*.+$)/) and ($arg[$i] !~ /^\s*print/) and ($arg[$i] !~ /\$#/)) {
            my $comment = $2;
            my $before_comment = $1 =~ s/\s*$//gr;
            $arg[$i] = $before_comment.'; '.$comment;
        }
        else {
            $arg[$i] = $arg[$i].';' if (((substr $arg[$i], -1) !~ /[\{\}\;]/) and ((substr $arg[$i], 0, 1) ne '#'));
        }
        push @arr, $arg[$i];
    }
    return @arr;
}

sub sys {
    my $str = shift @_;
    if (($str =~ /^\s*[a-z]+.*$/) and ($str !~ /^\s*exit/)) {
        return 'system "'.$str.'"';
    }
    if ($str =~ /^\s*[a-z]+\s\-[a-zA-Z]+.*/) {
        $str =~ s/\"//g;
        return 'system "'.$str.'"';
    }
    return $str;
}

sub test {
    my $str = shift @_;

    my %str_cmp = (
        '=' => 'eq',
        '==' => 'eq',
        '!=' => 'ne',
        '>' => 'gt',
        '<' => 'lt',
        '>=' => 'ge',
        '<=' => 'le'
    );

    my %int_cmp = (
        '-eq' => '==',
        '-ne' => '!=',
        '-gt' => '>',
        '-ge' => '>=',
        '-lt' => '<',
        '-le' => '<='
    );

    my $compare_str = '[=!~<>]+';
    my $compare_int = '-eq|-ne|-gt|-ge|-lt|-le';

    # for things like test __ < __, [ __ -gt __ ]...
    if ($str =~ /(.*)(test|\[)\s(.+)\s*($compare_str|$compare_int)\s([^\|&|\s]+)(.*)/) {
        my $start = $1 || '';
        my $var1 = $3;
        my $exp = $4;
        my $var2 = $5;
        my $end = $6 =~ s/\s*\]//r || '';
        #print "##\nSTART: $start\nVAR1: $var1\nEXP: $exp\nVAR2: $var2\nEND: $end\n";

        # string comparison only
        if ($exp =~ /$compare_str/) {
            $var1 =~ s/^(\'?\"?)([^\$"']+)(\'?\"?)/\"$2\"/;        # replace capture1 and capture3 with "
            $exp = $str_cmp{$exp} || $exp;                        # (var1 is not variable like $a $b etc)
            if ($exp eq '=~') {
                $var2 =~ s/(\'?\"?)(.*)(\'?\"?)/\/$2\//;           # replace capture1 and capture3 with /
            }
            else {
                $var2 =~ s/(\'?\"?)(\w+)(\'?\"?)/\"$2\"/;
            }
        }

        # numeric comparison only
        if ($exp =~ /$compare_int/) {
            $exp = $int_cmp{$exp} || $exp;
        }
        $var1 =~ s/\s*$//g;
        $var2 =~ s/\s*$//g;
        return $start.'('.$var1.' '.$exp.' '.$var2.')'.$end;

    }

    # For things like [ -z ___ ], test -f ___...
    if ($str =~ /(.*)(\[|test)\s(\!*\s*\-[A-Za-z]{1})\s(.+)/) {
        my $start = $1;
        my $cmd = $3;
        my $var = $4 =~ s/\s*\]//r;
        if ($var !~ /^\s*\$/) {
            return $start.'('.$cmd.' \''.$var.'\')';
        }
        return $start.'('.$cmd.' '.$var.')';

    }
    return $str;
}

sub var_assign {
    my $str = shift @_;
    if ($str =~ /^\s*\$?(\w+)\s*\=\s*(.+)/) {
        my $var_name = $1;
        my $value = $2;
        #print "var_name $1, value $2\n";
        return $str if ($value =~ /<.*>/);
        if ($value =~ /^\w+$/) {
            return '$'.$var_name.' = '.'"'.$value.'"'; 
        }
        elsif (($value =~ /$var_name/) and ($value !~ /^\$/)) {
            return '$'.$var_name.' = $'.$value;
        }
        else {
            return '$'.$var_name.' = '.$value;
        }
    }
    return $str;
}

sub var_assign_sys {
    my $str = shift @_;
    my $ret;
    if ($str =~ /(\$\w+) = \$\((.+)\)/) {
        my $ret = $1.' = `'.$2.'`';
        return 'chomp('.$ret.')';
    }
    return $str;
}


### OUTPUT ###
exit if (!@input);
print "#!/usr/bin/perl -w\n\n";

my @sub_names;

# ORDER DOES MATTER!
for my $line (@input) {
    $line =~ s/\s*$//;
    my $unchanged = $line;
    next if ($line =~/^#/); # skip comments
    $line = '`'.$line.'`' if ($line =~ />\/dev\//);
    next if ($line =~ />\/dev\//);
    $line = file_matching($line); # before for_loop
    $line = expr($line);
    $line = test($line); # test before ifs after expr
    $line = for_loop($line); #for loop before args
    $line = args($line); # before echo
    $line = reading($line);
    $line = cd($line);
    $line = if_while($line);
    $line = echo($line);
    $line = var_assign($line);
    ($line, @sub_names) = fx($line, @sub_names);
    if ($line eq $unchanged) {
        for my $s (@sub_names) {
            $line = sys($line) if ($line !~ /$s/); #not perfect ):
        }
    }
    $line = var_assign_sys($line);
}

my $sub_flag = 0;
my @sub_brackets;
for (my $i=0; $i<@input; $i++) {
    my $symbol = '(&&|\|\|)';
    if ($input[$i] =~ /^\s*$symbol\s*$/) {
        $input[$i-1] =~ s/\s*\{$//;
        $input[$i] = join ' ', $input[$i-1], $input[$i], $input[$i+1];
        splice(@input, $i-1, 1);
        $i=$i-1; # because previous element spliced, reset i
        splice(@input, $i+1, 1);
        #print "\n#### $input[$i] ####\n\n";
        if ($input[$i] =~ /^(if|while|elsif)\s*(.+)/) {
            my $ifs = $1;
            my $rest = $2;
            $rest =~ s/\(// if ($rest =~ /^\(\(/);
            $rest =~ s/\)\)/\)/;
            $input[$i] = $ifs.' ('.$rest.') {';
        }
        for my $s (@sub_names) { # if evaluating with sub
            $input[$i] =~ s/&&/or/g if ($input[$i] =~ /$s/);
        }
        if ($input[$i] =~ /(&&|\|\|)\1?/) {
            $input[$i] =~ s/&&/and/g;
            $input[$i] =~ s/\|\|/or/g;
        }
    }
    
    if ($input[$i] =~ /^sub/) {
        $sub_flag = 1; # flag now in subroutine
        push @sub_brackets, '{';
    }   
    if ($sub_flag == 1) {
        $input[$i] =~ s/\$ARGV\[(\d+)\]/\$_\[$1\]/; # Warning: won't work for all sub
        pop @sub_brackets if ($input[$i] =~ /}$/);
    }
    $sub_flag = 0 if (!@sub_brackets); # Turn flag off if all brackets balanced
    $input[$i] =~ s/^\s*//;
}

my @new = semicolon(@input);
my $indent = 0;
for my $line (@new) {
    if ($line =~ /^\(.+\)\;$/) {  # This is to handle one-line like [ $a = "abc" ] 
        $line =~ s/\;$//;
        $line = 'if ('.$line.') {}';
    }
    if (($line =~ /}$/) or ($line =~ /^}/)) {
        $indent--;
    }
    print "    " x $indent;
    print STDOUT "$line\n";
    if ($line =~ /{$/) {
        $indent++;
    }
}   


