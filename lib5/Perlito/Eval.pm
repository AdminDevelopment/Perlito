# Do not edit this file - Generated by Perlito 6.0
use v5;
use utf8;
use strict;
use warnings;
no warnings ('redefine', 'once', 'void', 'uninitialized', 'misc', 'recursion');
use Perlito::Perl5::Runtime;
our $MATCH = Perlito::Match->new();
{
package GLOBAL;
sub new { shift; bless { @_ }, "GLOBAL" }

# use v6 
;
{
package CompUnit;
sub new { shift; bless { @_ }, "CompUnit" }
sub name { $_[0]->{name} };
sub body { $_[0]->{body} };
sub eval { my $self = $_[0]; my $env = $_[1]; (my  $env1 = [{  }, @{($env || []) || []}]); for my $stmt ( @{$self->{body} || []} ) { $stmt->eval($env1) } }
}

;
{
package Val::Int;
sub new { shift; bless { @_ }, "Val::Int" }
sub int { $_[0]->{int} };
sub eval { my $self = $_[0]; my $env = $_[1]; (0+$self->{int}) }
}

;
{
package Val::Bit;
sub new { shift; bless { @_ }, "Val::Bit" }
sub bit { $_[0]->{bit} };
sub eval { my $self = $_[0]; my $env = $_[1]; $self->{bit} }
}

;
{
package Val::Num;
sub new { shift; bless { @_ }, "Val::Num" }
sub num { $_[0]->{num} };
sub eval { my $self = $_[0]; my $env = $_[1]; (0+$self->{num}) }
}

;
{
package Val::Buf;
sub new { shift; bless { @_ }, "Val::Buf" }
sub buf { $_[0]->{buf} };
sub eval { my $self = $_[0]; my $env = $_[1]; $self->{buf} }
}

;
{
package Lit::Block;
sub new { shift; bless { @_ }, "Lit::Block" }
sub sig { $_[0]->{sig} };
sub stmts { $_[0]->{stmts} };
sub eval { my $self = $_[0]; my $env = $_[1]; (my  $env1 = [{  }, @{($env || []) || []}]); for my $stmt ( @{$self->{stmts} || []} ) { $stmt->eval($env1) } }
}

;
{
package Lit::Array;
sub new { shift; bless { @_ }, "Lit::Array" }
sub array1 { $_[0]->{array1} };
sub eval { my $self = $_[0]; my $env = $_[1]; my  $List_a; for my $v ( @{$self->{array1} || []} ) { push( @{$List_a}, $v->eval($env) ) }; return($List_a) }
}

;
{
package Lit::Hash;
sub new { shift; bless { @_ }, "Lit::Hash" }
sub hash1 { $_[0]->{hash1} };
sub eval { my $self = $_[0]; my $env = $_[1]; my  $Hash_h; for my $field ( @{$self->{hash1} || []} ) { (my  $pair = $field->arguments()); ($Hash_h->{($pair->[0])->eval($env)} = ($pair->[1])->eval($env)) }; return($Hash_h) }
}

;
{
package Index;
sub new { shift; bless { @_ }, "Index" }
sub obj { $_[0]->{obj} };
sub index_exp { $_[0]->{index_exp} };
sub eval { my $self = $_[0]; my $env = $_[1]; ($self->{obj}->eval($env))->[$self->{index_exp}->eval($env)] }
}

;
{
package Lookup;
sub new { shift; bless { @_ }, "Lookup" }
sub obj { $_[0]->{obj} };
sub index_exp { $_[0]->{index_exp} };
sub eval { my $self = $_[0]; my $env = $_[1]; ($self->{obj}->eval($env))->{$self->{index_exp}->eval($env)} }
}

;
{
package Var;
sub new { shift; bless { @_ }, "Var" }
sub sigil { $_[0]->{sigil} };
sub twigil { $_[0]->{twigil} };
sub namespace { $_[0]->{namespace} };
sub name { $_[0]->{name} };
sub eval { my $self = $_[0]; my $env = $_[1]; (my  $ns = ''); if (Main::bool($self->{namespace})) { ($ns = $self->{namespace} . '::') } else { if (Main::bool((((($self->{sigil} eq '@')) && (($self->{twigil} eq '*'))) && (($self->{name} eq 'ARGS'))))) { return((\@ARGV)) } ; if (Main::bool(($self->{twigil} eq '.'))) { warn('Interpreter TODO: $.' . $self->{name}); return('$self->{' . $self->{name} . '}') } ; if (Main::bool(($self->{name} eq '/'))) { warn('Interpreter TODO: $/'); return($self->{sigil} . 'MATCH') }  }; (my  $name = $self->{sigil} . $ns . $self->{name}); for my $e ( @{[@{(($env) || []) || []}] || []} ) { if (Main::bool(exists($e->{$name}))) { return($e->{$name}) }  }; warn('Interpreter runtime error: variable \'', $name, '\' not found') };
sub plain_name { my $self = $_[0]; if (Main::bool($self->{namespace})) { return($self->{sigil} . $self->{namespace} . '::' . $self->{name}) } ; return($self->{sigil} . $self->{name}) }
}

;
{
package Proto;
sub new { shift; bless { @_ }, "Proto" }
sub name { $_[0]->{name} };
sub eval { my $self = $_[0]; my $env = $_[1]; ("" . $self->{name}) }
}

;
{
package Call;
sub new { shift; bless { @_ }, "Call" }
sub invocant { $_[0]->{invocant} };
sub hyper { $_[0]->{hyper} };
sub method { $_[0]->{method} };
sub arguments { $_[0]->{arguments} };
sub eval { my $self = $_[0]; my $env = $_[1]; warn('Interpreter TODO: Call'); (my  $invocant = $self->{invocant}->eval($env)); if (Main::bool(($invocant eq 'self'))) { ($invocant = '$self') } ; if (Main::bool(($self->{hyper}))) {  } else {  }; warn('Interpreter runtime error: method \'', $self->{method}, '()\' not found') }
}

;
{
package Apply;
sub new { shift; bless { @_ }, "Apply" }
sub code { $_[0]->{code} };
sub arguments { $_[0]->{arguments} };
sub namespace { $_[0]->{namespace} };
sub eval { my $self = $_[0]; my $env = $_[1]; (my  $ns = ''); if (Main::bool($self->{namespace})) { ($ns = $self->{namespace} . '::') } ; (my  $code = $ns . $self->{code}); for my $e ( @{[@{(($env) || []) || []}] || []} ) { if (Main::bool(exists($e->{$code}))) { return((($e->{$code})->($env, $self->{arguments}))) }  }; warn('Interpreter runtime error: subroutine \'', $code, '()\' not found') }
}

;
{
package If;
sub new { shift; bless { @_ }, "If" }
sub cond { $_[0]->{cond} };
sub body { $_[0]->{body} };
sub otherwise { $_[0]->{otherwise} };
sub eval { my $self = $_[0]; my $env = $_[1]; (my  $cond = $self->{cond}); if (Main::bool($cond->eval($env))) { (my  $env1 = [{  }, @{($env || []) || []}]); for my $stmt ( @{[@{((($self->{body})->stmts()) || []) || []}] || []} ) { $stmt->eval($env1) } } else { (my  $env1 = [{  }, @{($env || []) || []}]); for my $stmt ( @{[@{((($self->{otherwise})->stmts()) || []) || []}] || []} ) { $stmt->eval($env1) } }; return(undef) }
}

;
{
package For;
sub new { shift; bless { @_ }, "For" }
sub cond { $_[0]->{cond} };
sub body { $_[0]->{body} };
sub topic { $_[0]->{topic} };
sub eval { my $self = $_[0]; my $env = $_[1]; (my  $cond = $self->{cond}); (my  $topic_name = (($self->{body})->sig())->plain_name()); (my  $env1 = [{  }, @{($env || []) || []}]); for my $topic ( @{[@{(($cond->eval($env)) || []) || []}] || []} ) { ($env1->[0] = { ($topic_name => $topic) }); for my $stmt ( @{[@{((($self->{body})->stmts()) || []) || []}] || []} ) { $stmt->eval($env1) } }; return(undef) }
}

;
{
package When;
sub new { shift; bless { @_ }, "When" }
sub parameters { $_[0]->{parameters} };
sub body { $_[0]->{body} };
sub eval { my $self = $_[0]; my $env = $_[1]; die('TODO - When') }
}

;
{
package While;
sub new { shift; bless { @_ }, "While" }
sub init { $_[0]->{init} };
sub cond { $_[0]->{cond} };
sub continue { $_[0]->{continue} };
sub body { $_[0]->{body} };
sub eval { my $self = $_[0]; my $env = $_[1]; die('TODO - While') }
}

;
{
package Decl;
sub new { shift; bless { @_ }, "Decl" }
sub decl { $_[0]->{decl} };
sub type { $_[0]->{type} };
sub var { $_[0]->{var} };
sub eval { my $self = $_[0]; my $env = $_[1]; (my  $decl = $self->{decl}); (my  $name = $self->{var}->plain_name()); if (Main::bool(($decl eq 'has'))) { warn('Interpreter TODO: has') } ; if (Main::bool(((exists(($env->[0])->{$name})) ? 0 : 1))) { (($env->[0])->{$name} = undef) } ; return(undef) };
sub plain_name { my $self = $_[0]; $self->{var}->plain_name() }
}

;
{
package Sig;
sub new { shift; bless { @_ }, "Sig" }
sub invocant { $_[0]->{invocant} };
sub positional { $_[0]->{positional} };
sub named { $_[0]->{named} };
sub eval { my $self = $_[0]; my $env = $_[1]; warn('Interpreter TODO: Sig') }
}

;
{
package Method;
sub new { shift; bless { @_ }, "Method" }
sub name { $_[0]->{name} };
sub sig { $_[0]->{sig} };
sub block { $_[0]->{block} };
sub eval { my $self = $_[0]; my $env = $_[1]; warn('Interpreter TODO: Method'); (my  $sig = $self->{sig}); (my  $invocant = $sig->invocant()); (my  $pos = $sig->positional()); (my  $str = 'my $List__ = \\@_; ') }
}

;
{
package Sub;
sub new { shift; bless { @_ }, "Sub" }
sub name { $_[0]->{name} };
sub sig { $_[0]->{sig} };
sub block { $_[0]->{block} };
sub eval { my $self = $_[0]; my $env = $_[1]; my  $List_param_name; for my $field ( @{[@{(($self->{sig}->positional()) || []) || []}] || []} ) { push( @{$List_param_name}, $field->plain_name() ) }; (my  $sub = sub  { my $env = $_[0]; my $args = $_[1]; my  $Hash_context; (my  $n = 0); ($Hash_context->{'@_'} = $args); for my $name ( @{$List_param_name || []} ) { ($Hash_context->{$name} = ($args->[$n])->eval($env)); ($n = ($n + 1)) }; (my  $env1 = [%{$Hash_context || {}}, @{($env || []) || []}]); my  $r; for my $stmt ( @{$self->{block} || []} ) { ($r = $stmt->eval($env1)) }; return($r) }); if (Main::bool($self->{name})) { (($env->[0])->{$self->{name}} = $sub) } ; return($sub) }
}

;
{
package Do;
sub new { shift; bless { @_ }, "Do" }
sub block { $_[0]->{block} };
sub eval { my $self = $_[0]; my $env = $_[1]; (my  $env1 = [{  }, @{($env || []) || []}]); for my $stmt ( @{$self->{block} || []} ) { $stmt->eval($env1) } }
}

;
{
package Use;
sub new { shift; bless { @_ }, "Use" }
sub mod { $_[0]->{mod} };
sub eval { my $self = $_[0]; my $env = $_[1]; warn('Interpreter TODO: Use'); 'use ' . $self->{mod} }
}


}

1;
