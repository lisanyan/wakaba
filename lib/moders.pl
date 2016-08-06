# moders
use utf8;
my %moders;

$moders{Admin} = {
	class => 'admin',
	password => 'CHANGEME',
	boards => [] # leave array empty to allow access to every board
};

# $moders{sample} = {
# 	class => 'mod',
# 	password => 'lies',
# 	boards => ['a','b','ö']
# };

\%moders;
