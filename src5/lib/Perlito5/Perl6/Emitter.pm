use v5;

use Perlito5::AST;

package Perl6;
{
    sub tab {
        my $level = shift;
        "\t" x $level
    }

    my %safe_char = (
        '$' => 1,
        '%' => 1,
        '@' => 1,
        '&' => 1,
        '_' => 1,
        ',' => 1,
        '.' => 1,
        ':' => 1,
        ';' => 1,
        '-' => 1,
        '+' => 1,
        '*' => 1,
        ' ' => 1,
        '(' => 1,
        ')' => 1,
        '<' => 1,
        '=' => 1,
        '>' => 1,
        '[' => 1,
        ']' => 1,
        '{' => 1,
        '|' => 1,
        '}' => 1,
    );

    sub escape_string {
        my $s = shift;
        my @out;
        my $tmp = '';
        return "''" if $s eq '';
        for my $i (0 .. length($s) - 1) {
            my $c = substr($s, $i, 1);
            if  (  ($c ge 'a' && $c le 'z')
                || ($c ge 'A' && $c le 'Z')
                || ($c ge '0' && $c le '9')
                || exists( $safe_char{$c} )
                )
            {
                $tmp = $tmp . $c;
            }
            else {
                push @out, "'$tmp'" if $tmp ne '';
                push @out, "String.fromCharCode(" . ord($c) . ")";
                $tmp = '';
            }
        }
        push @out, "'$tmp'" if $tmp ne '';
        return join(' + ', @out);
    }

    sub autovivify {
        my $ast = shift;
        my $type = shift;

        my $str_init = "''";
        $str_init = '{}' if $type eq 'HASH';
        $str_init = '[]' if $type eq 'ARRAY';
        $str_init = 'new HashRef({})' if $type eq 'HASHREF';  # TODO use "real" reference
        $str_init = '[]' if $type eq 'ARRAYREF'; # TODO use "real" references

        if (  $ast->isa('Var') ) {
            if (  $type eq 'HASH'
               && $ast->sigil eq '$'
               )
            {
                # $a in the expression $a{'x'}
                $ast = Var->new( sigil => '%', namespace => $ast->namespace, name => $ast->name );
                my $var_js = $ast->emit_perl6;
                return [ 'if (' . $var_js . ' == null) { ' . $var_js . ' = ' . $str_init . ' }; ' ];
            }
            elsif ( $type eq 'ARRAY'
               && $ast->sigil eq '$'
               )
            {
                # $a in the expression $a[3]
                $ast = Var->new( sigil => '@', namespace => $ast->namespace, name => $ast->name );
                my $var_js = $ast->emit_perl6;
                return [ 'if (' . $var_js . ' == null) { ' . $var_js . ' = ' . $str_init . ' }; ' ];
            }
            elsif (  $type eq 'HASHREF'
               && $ast->sigil eq '$'
               )
            {
                # $a in the expression $a->{'x'}
                my $var_js = $ast->emit_perl6;
                return [ 'if (' . $var_js . ' == null) { ' . $var_js . ' = ' . $str_init . ' }; ' ];
            }
            elsif ( $type eq 'ARRAYREF'
               && $ast->sigil eq '$'
               )
            {
                # $a in the expression $a->[3]
                my $var_js = $ast->emit_perl6;
                return [ 'if (' . $var_js . ' == null) { ' . $var_js . ' = ' . $str_init . ' }; ' ];
            }
        }
        elsif ($ast->isa( 'Call' )) {
            my $var_js = $ast->emit_perl6;
            if  (  $ast->method eq 'postcircumfix:<[ ]>' ) {
                # $a->[3]
                return [ @{ autovivify( $ast->invocant, 'ARRAYREF' ) },
                         'if (' . $var_js . ' == null) { ' . $var_js . ' = ' . $str_init . ' }; '
                       ];
            }
            elsif  (  $ast->method eq 'postcircumfix:<{ }>' ) {
                # $a->{x}
                return [ @{ autovivify( $ast->invocant, 'HASHREF' ) },
                         'if (' . $var_js . ' == null) { ' . $var_js . ' = ' . $str_init . ' }; '
                       ];
            }
        }
        elsif ($ast->isa( 'Index' )) {
            my $var_js = $ast->emit_perl6;
            # $a[3][4]

            my $type;
            my $var = $ast->obj;

            if (  $var->isa('Var')
               && $var->sigil eq '$'
               )
            {
                $type = 'ARRAY';
            }
            else {
                $type = 'ARRAYREF';
            }

            return [ @{ autovivify( $ast->obj, $type ) },
                     'if (' . $var_js . ' == null) { ' . $var_js . ' = ' . $str_init . ' }; '
                   ]
        }
        elsif ($ast->isa( 'Lookup' )) {
            my $var_js = $ast->emit_perl6;
            # $a{'x'}{'y'}

            my $type;
            my $var = $ast->obj;

            if (  $var->isa('Var')
               && $var->sigil eq '$'
               )
            {
                $type = 'HASH';
            }
            else {
                $type = 'HASHREF';
            }

            return [ @{ autovivify( $var, $type ) },
                     'if (' . $var_js . ' == null) { ' . $var_js . ' = ' . $str_init . ' }; '
                   ]
        }
        return [];
    }

    sub to_str {
            my $cond = shift;
            if ($cond->isa( 'Val::Buf' )) {
                return $cond->emit_perl6;
            }
            else {
                return 'string(' . $cond->emit_perl6 . ')';
            }
    }
    sub to_num {
            my $cond = shift;
            if ($cond->isa( 'Val::Int' ) || $cond->isa( 'Val::Num' )) {
                return $cond->emit_perl6;
            }
            else {
                return 'num(' . $cond->emit_perl6 . ')';
            }
    }
    sub to_bool {
            my $cond = shift;
            if  (  ($cond->isa( 'Val::Int' ))
                || ($cond->isa( 'Val::Num' ))
                || ($cond->isa( 'Apply' ) && $cond->code eq 'infix:<||>')
                || ($cond->isa( 'Apply' ) && $cond->code eq 'infix:<&&>')
                || ($cond->isa( 'Apply' ) && $cond->code eq 'prefix:<!>')
                )
            {
                return $cond->emit_perl6;
            }
            else {
                return 'bool(' . $cond->emit_perl6 . ')';
            }
    }

}

package Perlito5::Perl6::LexicalBlock;
{
    sub new { my $class = shift; bless {@_}, $class }
    sub block { $_[0]->{'block'} }
    sub needs_return { $_[0]->{'needs_return'} }
    sub top_level { $_[0]->{'top_level'} }

    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;

        if ($self->{"top_level"}) {
            my $block = Perlito5::Perl6::LexicalBlock->new( block => $self->block, needs_return => $self->needs_return, top_level => 0 );
            return
                  Perl6::tab($level)   . 'try {' . "\n"
                .                               $block->emit_perl6_indented( $level + 1 ) . ';' . "\n"
                . Perl6::tab($level)   . '}' . "\n"
                . Perl6::tab($level)   . 'catch(err) {' . "\n"
                . Perl6::tab($level + 1)   . 'if ( err instanceof Error ) {' . "\n"
                . Perl6::tab($level + 2)       . 'throw(err);' . "\n"
                . Perl6::tab($level + 1)   . '}' . "\n"
                . Perl6::tab($level + 1)   . 'else {' . "\n"
                . Perl6::tab($level + 2)       . 'return(err);' . "\n"
                . Perl6::tab($level + 1)   . '}' . "\n"
                . Perl6::tab($level)   . '}';
        }

        my @block;
        for (@{$self->{"block"}}) {
            if (defined($_)) {
                push @block, $_
            }
        }
        if (!@block) {
            return Perl6::tab($level) . 'null;';
        }
        my @str;
        for my $decl ( @block ) {
            if ($decl->isa( 'Decl' ) && $decl->decl eq 'my') {
                push @str, Perl6::tab($level) . $decl->emit_perl6_init;
            }
            if ($decl->isa( 'Apply' ) && $decl->code eq 'infix:<=>') {
                my $var = $decl->arguments[0];
                if ($var->isa( 'Decl' ) && $var->decl eq 'my') {
                    push @str, Perl6::tab($level) . $var->emit_perl6_init;
                }
            }
        }
        my $last_statement;
        if ($self->{"needs_return"}) {
            $last_statement = pop @block;
        }
        for my $decl ( @block ) {
            if (!( $decl->isa( 'Decl' ) && $decl->decl eq 'my' )) {
                push @str, $decl->emit_perl6_indented($level) . ';';
            }
        }
        if ($self->{"needs_return"} && $last_statement) {
            if ($last_statement->isa( 'If' )) {
                my $cond      = $last_statement->cond;
                my $body      = $last_statement->body;
                my $otherwise = $last_statement->otherwise;
                if ($cond->isa( 'Var' ) && $cond->sigil eq '@') {
                    $cond = Apply->new( code => 'prefix:<@>', arguments => [ $cond ] );
                }
                $body      = Perlito5::Perl6::LexicalBlock->new( block => $body->stmts, needs_return => 1 );
                push @str, Perl6::tab($level) .
                        'if ( ' . Perl6::to_bool( $cond ) . ' ) { return (function () {' . "\n"
                        .       $body->emit_perl6_indented($level+1) . "\n"
                        . Perl6::tab($level) . '})(); }';
                if ($otherwise) {
                    $otherwise = Perlito5::Perl6::LexicalBlock->new( block => $otherwise->stmts, needs_return => 1 );
                    push @str,
                          Perl6::tab($level) . 'else { return (function () {' . "\n"
                        .       $otherwise->emit_perl6_indented($level+1) . "\n"
                        . Perl6::tab($level) . '})(); }';
                }
            }
            elsif  $last_statement->isa( 'Apply' ) && $last_statement->code eq 'return'
                || $last_statement->isa( 'For' )
                || $last_statement->isa( 'While' )
            {
                # Return, For - no changes for now
                push @str, $last_statement->emit_perl6_indented($level)
            }
            else {
                push @str, Perl6::tab($level) . 'return(' . $last_statement->emit_perl6() . ')'
            }
        }
        return join("\n", @str) . ';';
    }
}

package CompUnit;
{
    sub emit_perl6 { 
        my $self = $_[0];
        $self->emit_perl6_indented(0) 
    }
    sub emit_perl6_indented {
        my $self = $_[0];
        my $level = $_[1];

        # process 'package' statements
        my @body;
        my $i = 0;
        while ( $i <= scalar @{$self->{"body"}} ) {
            my $stmt = $self->{"body"}->[$i];
            if ( ref($stmt) eq 'Apply' && $stmt->code eq 'package' ) {
                # found an inner package
                my $name = $stmt->namespace;
                my @stmts;
                $i++;
                while (  $i <= scalar( @{$self->{"body"}} )
                      && !( ref($self->{"body"}->[$i]) eq 'Apply' && $self->{"body"}->[$i]->code eq 'package' )
                      )
                {
                    push @stmts, $self->{"body"}->[$i];
                    $i++;
                }
                push @body, CompUnit->new( name => $name, body => \@stmts );
            }
            else {
                push @body, $stmt
                    if defined $stmt;  # TODO find where undefined stmts come from
                $i++;
            }
        }

        my $class_name = $self->{"name"};
        my $str = 'make_package("' . $class_name . '");' . "\n"
            . '(function () {' . "\n"
            . '  var __PACKAGE__ = "' . $class_name . '";' . "\n"
            . '  var v__NAMESPACE = NAMESPACE[__PACKAGE__];' . "\n";

        for my $decl ( @body ) {
            if ($decl->isa( 'Decl' ) && ( $decl->decl eq 'my' )) {
                $str = $str . '  ' . $decl->emit_perl6_init;
            }
            if ($decl->isa( 'Apply' ) && $decl->code eq 'infix:<=>') {
                my $var = $decl->arguments[0];
                if ($var->isa( 'Decl' ) && $var->decl eq 'my') {
                    $str = $str . '  ' . $var->emit_perl6_init;
                }
            }
        }
        for my $decl ( @body ) {
            if ($decl->isa( 'Sub' )) {
                $str = $str . ($decl)->emit_perl6_indented( $level + 1 ) . ";\n";
            }
        }
        for my $decl ( @body ) {
            if (  defined( $decl )
               && (!( $decl->isa( 'Decl' ) && $decl->decl eq 'my' ))
               && (!( $decl->isa( 'Sub')))
               )
            {
                $str = $str . ($decl)->emit_perl6_indented( $level + 1 ) . ";\n";
            }
        }
        $str = $str . '}'
            . ')()' . "\n";
    }
    sub emit_perl6_program {
        my $comp_units = shift;
        my $str = '';
        for my $comp_unit ( @$comp_units ) {
            $str = $str . $comp_unit->emit_perl6() . "\n";
        }
        return $str;
    }
}

package Val::Int;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift; Perl6::tab($level) . $self->{"int"} }
}

package Val::Num;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift; Perl6::tab($level) . $self->{"num"} }
}

package Val::Buf;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift; Perl6::tab($level) . Perl6::escape_string($self->{"buf"}) }
}

package Lit::Block;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;
        my $sig = 'v__';
        if ($self->{"sig"}) {
            $sig = $self->{"sig"}->emit_perl6_indented( $level + 1 );
        }
        return
              Perl6::tab($level) . "(function ($sig) \{\n"
            .   (Perlito5::Perl6::LexicalBlock->new( block => $self->{"stmts"}, needs_return => 1 ))->emit_perl6_indented( $level + 1 ) . "\n"
            . Perl6::tab($level) . '})'
    }
}

package Lit::Array;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;
        my $ast = $self->expand_interpolation;
        return $ast->emit_perl6_indented( $level );
    }
}

package Lit::Hash;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;
        my $ast = $self->expand_interpolation;
        return $ast->emit_perl6_indented( $level );
    }
}

package Index;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;

        if (  $self->{"obj"}->isa('Var')
           && $self->{"obj"}->sigil eq '$'
           )
        {
            my $v = Var->new( sigil => '@', namespace => $self->{"obj"}->namespace, name => $self->{"obj"}->name );
            return $v->emit_perl6_indented($level) . '[' . $self->{"index_exp"}->emit_perl6() . ']';
        }

        Perl6::tab($level) . $self->{"obj"}->emit_perl6() . '[' . $self->{"index_exp"}->emit_perl6() . ']';
    }
}

package Lookup;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;
        # my $var = $self->{"obj"}->emit_perl6;
        # return $var . '[' . $self->{"index_exp"}->emit_perl6() . ']'

        if (  $self->{"obj"}->isa('Var')
           && $self->{"obj"}->sigil eq '$'
           )
        {
            my $v = Var->new( sigil => '%', namespace => $self->{"obj"}->namespace, name => $self->{"obj"}->name );
            return $v->emit_perl6_indented($level) . '[' . $self->{"index_exp"}->emit_perl6() . ']';
        }
        return $self->{"obj"}->emit_perl6_indented($level) . '._hash_[' . $self->{"index_exp"}->emit_perl6() . ']';
    }
}

package Var;
{
    my $table = {
        '$' => 'v_',
        '@' => 'List_',
        '%' => 'Hash_',
        '&' => 'Code_',
    }

    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;

        if ( $self->{"sigil"} eq '*' ) {
            my $ns = 'v__NAMESPACE';
            if ($self->{"namespace"}) {
                $ns = 'NAMESPACE["' . $self->{"namespace"} . '"]';
            }
            return $ns . '["' . $self->{"name"} . '"]';
        }

        my $ns = '';
        if ($self->{"namespace"}) {
            $ns = 'NAMESPACE["' . $self->{"namespace"} . '"].';
        }
        $ns . $table->{$self->{"sigil"}} . $self->{"name"}
    }
    sub plain_name {
        my $self = shift;
        if ($self->namespace) {
            return $self->namespace . '.' . $self->name
        }
        return $self->name
    }
}

package Proto;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;
        Perl6::tab($level) . 'CLASS["' . $self->{"name"} . '"]'
    }
}

package Call;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;
        my $invocant = $self->{"invocant"}->emit_perl6;
        my $meth = $self->{"method"};

        if ( $meth eq 'postcircumfix:<[ ]>' ) {
            return Perl6::tab($level) . $invocant . '[' . $self->{"arguments"}->emit_perl6() . ']'
        }
        if ( $meth eq 'postcircumfix:<{ }>' ) {
            return Perl6::tab($level) . $invocant . '._hash_[' . $self->{"arguments"}->emit_perl6() . ']'
        }
        if  ($meth eq 'postcircumfix:<( )>')  {
            my @args = ();
            push @args, $_->emit_perl6
                for @{$self->{"arguments"}};
            return Perl6::tab($level) . '(' . $invocant . ')(' . join(',', @args) . ')';
        }
        # try to call a method on the class; if that fails, then call a 'native js' method
        my @args = ($invocant);
        push @args, $_->emit_perl6
            for @{$self->{"arguments"}};
        return Perl6::tab($level) . $invocant . '._class_.' . $meth . '(' . join(',', @args) . ')'
    }
}

package Apply;
{

    my %op_infix_js = (
        'infix:<->'  => ' - ',
        'infix:<*>'  => ' * ',
        'infix:</>'  => ' / ',
        'infix:<>>'  => ' > ',
        'infix:<<>'  => ' < ',
        'infix:<>=>' => ' >= ',
        'infix:<<=>' => ' <= ',

        'infix:<eq>' => ' == ',
        'infix:<ne>' => ' != ',
        'infix:<le>' => ' <= ',
        'infix:<ge>' => ' >= ',

        'infix:<==>' => ' == ',
        'infix:<!=>' => ' != ',
    );

    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;

        my $apply = $self->op_assign();
        if ($apply) {
            return $apply->emit_perl6_indented( $level );
        }

        my $code = $self->{"code"};

        if (ref $code ne '') {
            my @args = ();
            push @args, $_->emit_perl6
                for @{$self->{"arguments"}};
            return Perl6::tab($level) . '(' . $self->{"code"}->emit_perl6() . ')(' . join(',', @args) . ')';
        }
        if ($code eq 'infix:<=>>') {
            return Perl6::tab($level) . join(', ', map( $_->emit_perl6, @{$self->{"arguments"}} ))
        }
        if (exists $op_infix_js{$code}) {
            return Perl6::tab($level) . '(' 
                . join( $op_infix_js{$code}, map( $_->emit_perl6, @{$self->{"arguments"}} ))
                . ')'
        }

        if ($code eq 'eval') {
            return
                'eval(perl5_to_js(' 
                    . Perl6::to_str($self->{"arguments"}->[0])
                . '))'
        }

        if ($code eq 'undef')      { return Perl6::tab($level) . 'null' }
        if ($code eq 'defined')    { return Perl6::tab($level) . '('  . join(' ', map( $_->emit_perl6, @{$self->{"arguments"}} ))    . ' != null)' }

        if ($code eq 'shift')      {
            if ( $self->{"arguments"} && @{$self->{"arguments"}} ) {
                return 'v__NAMESPACE.shift(' . join(', ', map( $_->emit_perl6, @{$self->{"arguments"}} )) . ')'
            }
            return 'v__NAMESPACE.shift(List__)'
        }

        if ($code eq 'map') {
            my $fun  = $self->{"arguments"}->[0];
            my $list = $self->{"arguments"}->[1];
            return
                    '(function (a_) { '
                        . 'var out = []; '
                        . 'if ( a_ == null ) { return out; }; '
                        . 'for(var i = 0; i < a_.length; i++) { '
                            . 'var v__ = a_[i]; '
                            . 'out.push(' . $fun->emit_perl6 . ')'
                        . '}; '
                        . 'return out;'
                    . ' })(' . $list->emit_perl6() . ')'
        }

        if ( $code eq 'prefix:<!>' ) {
            return '( ' . Perl6::to_bool( $self->{"arguments"}->[0] ) . ' ? false : true)';
        }

        if ( $code eq 'prefix:<$>' ) {
            my $arg = $self->{"arguments"}->[0];
            return '(' . $arg->emit_perl6 . ')._scalar_';
        }
        if ( $code eq 'prefix:<@>' ) {
            return '(' . join( ' ', map( $_->emit_perl6, @{ $self->{"arguments"} } ) ) . ')';
        }
        if ( $code eq 'prefix:<%>' ) {
            my $arg = $self->{"arguments"}->[0];
            return '(' . $arg->emit_perl6 . ')._hash_';
        }

        if ( $code eq 'circumfix:<[ ]>' ) {
            return 'Array.prototype.slice.call(' . join( ', ', map( $_->emit_perl6, @{ $self->{"arguments"} } ) ) . ')';
        }
        if ( $code eq 'prefix:<\\>' ) {
            my $arg = $self->{"arguments"}->[0];
            if ( $arg->isa('Var') ) {
                if ( $arg->sigil eq '@' ) {
                    # XXX not implemented
                    return $arg->emit_perl6;
                }
                if ( $arg->sigil eq '%' ) {
                    return '(new HashRef(' . $arg->emit_perl6 . '))';
                }
            }
            # XXX \&x should return a CODE ref
            return '(new ScalarRef(' . $arg->emit_perl6 . '))';
        }

        if ($code eq 'postfix:<++>') { return '('   . join(' ', map( $_->emit_perl6, @{$self->{"arguments"}} ))  . ')++' }
        if ($code eq 'postfix:<-->') { return '('   . join(' ', map( $_->emit_perl6, @{$self->{"arguments"}} ))  . ')--' }
        if ($code eq 'prefix:<++>')  { return '++(' . join(' ', map( $_->emit_perl6, @{$self->{"arguments"}} ))  . ')' }
        if ($code eq 'prefix:<-->')  { return '--(' . join(' ', map( $_->emit_perl6, @{$self->{"arguments"}} ))  . ')' }

        if ($code eq 'infix:<x>')  { return 'str_replicate(' . join(', ', map( $_->emit_perl6, @{$self->{"arguments"}} ))  . ')' }

        if ($code eq 'list:<.>')
        { 
            return '('  
                . join( ' + ',
                        map( Perl6::to_str($_), @{$self->{"arguments"}} )
                      )
                . ')' 
        }

        if ($code eq 'infix:<+>')  { return 'add' . '('  . join(', ', map( $_->emit_perl6, @{$self->{"arguments"}} ))  . ')' }
        if ($code eq 'prefix:<+>') { return '('  . $self->{"arguments"}->[0]->emit_perl6()  . ')' }

        if ($code eq 'infix:<..>') {
            return '(function (a) { '
                    . 'for (var i=' . $self->{"arguments"}->[0]->emit_perl6()
                           . ', l=' . $self->{"arguments"}->[1]->emit_perl6() . '; '
                       . 'i<=l; ++i)'
                    . '{ '
                        . 'a.push(i) '
                    . '}; '
                    . 'return a '
                . '})([])'
        }

        if   $code eq 'infix:<&&>'
          || $code eq 'infix:<and>'
        {
            return 'and' . '('
                . $self->{"arguments"}->[0]->emit_perl6() . ', '
                . 'function () { return ' . $self->{"arguments"}->[1]->emit_perl6() . '; })'
        }
        if   $code eq 'infix:<||>'
          || $code eq 'infix:<or>'
        {
            return 'or' . '('
                . $self->{"arguments"}->[0]->emit_perl6() . ', '
                . 'function () { return ' . $self->{"arguments"}->[1]->emit_perl6() . '; })'
        }
        if ($code eq 'infix:<//>') { return ('defined_or') . '('
                . $self->{"arguments"}->[0]->emit_perl6() . ', '
                . 'function () { return ' . $self->{"arguments"}->[1]->emit_perl6() . '; })'
        }

        if ($code eq 'exists') {
            my $arg = $self->{"arguments"}->[0];
            if ($arg->isa( 'Lookup' )) {
                my $v = $arg->obj;
                if (  $v->isa('Var')
                   && $v->sigil eq '$'
                   )
                {
                    $v = Var->new( sigil => '%', namespace => $v->namespace, name => $v->name );
                    return '(' . $v->emit_perl6() . ').hasOwnProperty(' . ($arg->index_exp)->emit_perl6() . ')';
                }
                return '(' . $v->emit_perl6() . ')._hash_.hasOwnProperty(' . ($arg->index_exp)->emit_perl6() . ')';
            }
            if ($arg->isa( 'Call' )) {
                if ( $arg->method eq 'postcircumfix:<{ }>' ) {
                    return '(' . $arg->invocant->emit_perl6() . ')._hash_.hasOwnProperty(' . $arg->{"arguments"}->emit_perl6() . ')';
                }
            }
        }
        if ($code eq 'ternary:<?? !!>') {
            return Perl6::tab($level) 
                 . '( ' . Perl6::to_bool( $self->{"arguments"}->[0] )
                 . ' ? ' . ($self->{"arguments"}->[1])->emit_perl6()
                 . ' : ' . ($self->{"arguments"}->[2])->emit_perl6()
                 . ')'
        }
        if ($code eq 'circumfix:<( )>') {
            return Perl6::tab($level) . '(' . join(', ', map( $_->emit_perl6, @{$self->{"arguments"}} )) . ')';
        }
        if ($code eq 'infix:<=>') {
            return emit_perl6_bind( $self->{"arguments"}->[0], $self->{"arguments"}->[1], $level );
        }
        if ($code eq 'return') {
            return Perl6::tab($level) . 'throw('
                .   ( $self->{"arguments"} && @{$self->{"arguments"}} 
                    ? $self->{"arguments"}->[0]->emit_perl6() 
                    : 'null'
                    )
                . ')'
        }

        if ($self->{"namespace"}) {

            if (  $self->{"namespace"} eq 'JS' 
               && $code eq 'inline'
               ) 
            {
                if ( $self->{"arguments"}->[0]->isa('Val::Buf') ) {
                    # JS::inline('var x = 123')
                    return $self->{"arguments"}[0]{"buf"};
                }
                else {
                    die "JS::inline needs a string constant";
                }
            }

            $code = 'NAMESPACE["' . $self->{"namespace"} . '"].' . ( $code );
        }
        else {
            $code = 'v__NAMESPACE.' . $code
        }
        my @args = ();
        push @args, $_->emit_perl6
            for @{$self->{"arguments"}};
        Perl6::tab($level) . $code . '(' . join(', ', @args) . ')';
    }

    sub emit_perl6_bind {
        my $parameters = shift;
        my $arguments = shift;
        my $level = shift;

        # if ($arguments->isa( 'Apply' )) {
        #     if (  $arguments->{"namespace"} eq 'JS' 
        #        && $arguments->{"code"} eq 'inline'
        #        ) 
        #     {
        #         if ( $arguments->{"arguments"}->[0]->isa('Val::Buf') ) {
        #             # $v = JS::inline('123')
        #             return '(' . $parameters->emit_perl6 . ' = ' . $arguments->{"arguments"}[0]{"buf"} . ')';
        #         }
        #         else {
        #             die "JS::inline needs a string constant";
        #         }
        #     }
        # }

        if ($parameters->isa( 'Call' )) {

            # $a->[3] = 4
            if  (  $parameters->method eq 'postcircumfix:<[ ]>' ) {
                my $str = '';
                my $var_js = $parameters->invocant->emit_perl6;
                my $auto = Perl6::autovivify( $parameters, 'ARRAYREF' );
                pop @$auto;
                $str = $str . join( '', @$auto );
                my $index_js = $parameters->arguments->emit_perl6;
                $str = $str . 'return (' . $var_js . '[' . $index_js . '] ' . ' = ' . $arguments->emit_perl6() . '); ';
                return Perl6::tab($level) . '(function () { ' . $str . '})()';
            }
 
            # $a->{x} = 4
            if  (  $parameters->method eq 'postcircumfix:<{ }>' ) {
                my $str = '';
                my $var_js = $parameters->invocant->emit_perl6;
                my $auto = Perl6::autovivify( $parameters, 'HASHREF' );
                pop @$auto;
                $str = $str . join( '', @$auto );
                my $index_js = $parameters->arguments->emit_perl6;
                $str = $str . 'return (' . $var_js . '._hash_[' . $index_js . '] ' . ' = ' . $arguments->emit_perl6() . '); ';
                return Perl6::tab($level) . '(function () { ' . $str . '})()';
            }

        }
        if ($parameters->isa( 'Lookup' )) {
            my $str = '';
            my $var = $parameters->obj;

            if (  $var->isa('Var')
               && $var->sigil eq '$'
               )
            {
                $var = Var->new( sigil => '%', namespace => $var->namespace, name => $var->name );
                my $var_js = $var->emit_perl6;
                my $auto = Perl6::autovivify( $parameters, 'HASHREF' );
                pop @$auto;
                $str = $str . join( '', @$auto );
                my $index_js = $parameters->index_exp->emit_perl6;
                $str = $str . 'return (' . $var_js . '[' . $index_js . '] ' . ' = ' . $arguments->emit_perl6() . '); ';
                return Perl6::tab($level) . '(function () { ' . $str . '})()';
           }

            my $var_js = $var->emit_perl6;
            my $auto = Perl6::autovivify( $parameters, 'HASHREF' );
            pop @$auto;
            $str = $str . join( '', @$auto );
            my $index_js = $parameters->index_exp->emit_perl6;
            $str = $str . 'return (' . $var_js . '._hash_[' . $index_js . '] ' . ' = ' . $arguments->emit_perl6() . '); ';
            return Perl6::tab($level) . '(function () { ' . $str . '})()';
        }
        if ($parameters->isa( 'Index' )) {
            my $str = '';
            my $var = $parameters->obj;

            if (  $var->isa('Var')
               && $var->sigil eq '$'
               )
            {
                $var = Var->new( sigil => '@', namespace => $var->namespace, name => $var->name );
            }

            my $var_js = $var->emit_perl6;
            my $auto = Perl6::autovivify( $parameters, 'ARRAYREF' );
            pop @$auto;
            $str = $str . join( '', @$auto );
            my $index_js = $parameters->index_exp->emit_perl6;
            $str = $str . 'return (' . $var_js . '[' . $index_js . '] ' . ' = ' . $arguments->emit_perl6() . '); ';
            return Perl6::tab($level) . '(function () { ' . $str . '})()';
        }
        if      $parameters->isa( 'Var' ) && $parameters->sigil eq '@'
            ||  $parameters->isa( 'Decl' ) && $parameters->var->sigil eq '@'
        {
            $arguments = Apply->new(
                            code => 'prefix:<@>', 
                            arguments => [ Lit::Array->new( array1 => [$arguments] ) ]
                        );
            return Perl6::tab($level) . '(' . $parameters->emit_perl6() . ' = (' . $arguments->emit_perl6() . ').slice())';
        }
        elsif   $parameters->isa( 'Var' ) && $parameters->sigil eq '%'
            ||  $parameters->isa( 'Decl' ) && $parameters->var->sigil eq '%'
        {
            $arguments = Apply->new( 
                            code => 'prefix:<%>', 
                            arguments => [ Lit::Hash->new( hash1 => [$arguments] ) ] 
                        );
            return Perl6::tab($level) . '(' 
                . $parameters->emit_perl6() . ' = (function (_h) { '
                .   'var _tmp = {}; '
                .   'for (var _i in _h) { '
                .       '_tmp[_i] = _h[_i]; '
                .   '}; '
                .   'return _tmp; '
                . '})( ' . $arguments->emit_perl6() . '))';
        }
        Perl6::tab($level) . '(' . $parameters->emit_perl6() . ' = ' . $arguments->emit_perl6() . ')';
    }
}

package If;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;
        my $cond = $self->{"cond"};
        if (  $cond->isa( 'Var' )
           && $cond->sigil eq '@'
           )
        {
            $cond = Apply->new( code => 'prefix:<@>', arguments => [ $cond ] );
        }
        my $body  = Perlito5::Perl6::LexicalBlock->new( block => $self->{"body"}->stmts, needs_return => 0 );
        my $s = Perl6::tab($level) . 'if ( ' . Perl6::to_bool( $cond ) . ' ) { '
            . '(function () {' . "\n"
            .       $body->emit_perl6_indented( $level + 1 ) . "\n"
            . Perl6::tab($level) . '})(); }';
        if ( @{ $self->{"otherwise"}->stmts } ) {
            my $otherwise = Perlito5::Perl6::LexicalBlock->new( block => $self->{"otherwise"}->stmts, needs_return => 0 );
            $s = $s
                . "\n"
                . Perl6::tab($level) . 'else { '
                .   '(function () {' . "\n"
                .       $otherwise->emit_perl6_indented( $level + 1 ) . "\n"
                . Perl6::tab($level) . '})(); }';
        }
        return $s;
    }
}


package While;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;
        my $body      = Perlito5::Perl6::LexicalBlock->new( block => $self->{"body"}->stmts, needs_return => 0 );
        return
           Perl6::tab($level) . 'for ( '
        .  ( $self->{"init"}     ? $self->{"init"}->emit_perl6()           . '; '  : '; ' )
        .  ( $self->{"cond"}     ? Perl6::to_bool( $self->{"cond"} )       . '; '  : '; ' )
        .  ( $self->{"continue"} ? $self->{"continue"}->emit_perl6()       . ' '   : ' '  )
        .  ') { '
            . '(function () {' . "\n" . $body->emit_perl6_indented( $level + 1 )      . ' })()'
        . ' }'
    }
}

package For;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;
        my $cond = $self->{"cond"};
        if (!( $cond->isa( 'Var' ) && $cond->sigil eq '@' )) {
            $cond = Lit::Array->new( array1 => [$cond] )
        }
        my $body      = Perlito5::Perl6::LexicalBlock->new( block => $self->{"body"}->stmts, needs_return => 0 );
        my $sig = 'v__';
        if ($self->{"body"}->sig()) {
            $sig = $self->{"body"}->sig->emit_perl6_indented( $level + 1 );
        }
        Perl6::tab($level) . '(function (a_) { for (var i_ = 0; i_ < a_.length ; i_++) { '
            . "(function ($sig) {\n"
                . $body->emit_perl6_indented( $level + 1 )
            . ' })(a_[i_]) } })'
        . '(' . $cond->emit_perl6() . ')'
    }
}

package Decl;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;
        Perl6::tab($level) . $self->{"var"}->emit_perl6;
    }
    sub emit_perl6_init {
        my $self = shift;
        if ($self->{"decl"} eq 'my') {
            my $str = "";
            $str = $str . 'var ' . ($self->{"var"})->emit_perl6() . ' = ';
            if ($self->{"var"})->sigil eq '%' {
                $str = $str . '{};' . "\n";
            }
            elsif ($self->{"var"})->sigil eq '@' {
                $str = $str . '[];' . "\n";
            }
            else {
                $str = $str . 'null;' . "\n";
            }
            return $str;
        }
        else {
            die "not implemented: Decl '" . $self->{"decl"} . "'";
        }
    }
}

package Sub;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;

        my $s =                     'function () {' . "\n"
        . Perl6::tab($level + 1) . 'var List__ = Array.prototype.slice.call(arguments);' . "\n"
        .   (Perlito5::Perl6::LexicalBlock->new( block => $self->{"block"}, needs_return => 1, top_level => 1 ))->emit_perl6_indented( $level + 1 ) . "\n"
        . Perl6::tab($level) . '}';

        ( $self->{"name"}
          ? 'make_sub(__PACKAGE__, "' . $self->{"name"} . '", ' . $s . ')'
          : $s
        )

    }
}

package Do;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;
        my $block = $self->simplify->block;
        return
              Perl6::tab($level) . '(function () {' . "\n"
            .   (Perlito5::Perl6::LexicalBlock->new( block => $block, needs_return => 1 ))->emit_perl6_indented( $level + 1 ) . "\n"
            . Perl6::tab($level) . '})()'
    }
}

package Use;
{
    sub emit_perl6 { $_[0]->emit_perl6_indented(0) }
    sub emit_perl6_indented {
        my $self = shift;
        my $level = shift;
        Perl6::tab($level) . '// use ' . $self->{"mod"} . "\n"
    }
}

=begin

=head1 NAME

Perlito5::Perl6::Emit - Code generator for Perlito Perl5-in-Perl6

=head1 SYNOPSIS

    $program->emit_perl6()  # generated Perl5 code

=head1 DESCRIPTION

This module generates Perl6 code for the Perlito Perl 5 compiler.

=head1 AUTHORS

Flavio Soibelmann Glock <fglock@gmail.com>.
The Pugs Team E<lt>perl6-compiler@perl.orgE<gt>.

=head1 COPYRIGHT

Copyright 2006, 2009, 2011 by Flavio Soibelmann Glock, Audrey Tang and others.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=end
