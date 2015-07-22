#!/usr/bin/perl

### echo 1 > /proc/sys/net/ipv4/tcp_tw_recycle 
#    Enable fast recycling TIME-WAIT sockets. Default value is 0.
#    It should not be changed without advice/request of technical
#    experts.

use strict;
use warnings;
use Data::Dumper;
use JSON::XS ();
use LWP ();
use POSIX;
use IO::Socket;
use IO::Socket::SSL ();

use constant {
#     CONFIG_FILE_DEFAULT => '/etc/unifi_proxy/unifi_proxy.conf',
     CONFIG_FILE_DEFAULT => './unifi_proxy.conf',
     TOOL_HOMEPAGE => 'https://github.com/zbx-sadman/unifi_proxy',
     TOOL_NAME => 'UniFi Proxy',
     TOOL_VERSION => '1.0.0',
#     TOOL_UA => 'UniFi Proxy 1.0.0',

     ACT_PERCENT => 'percent',
     ACT_COUNT => 'count',
     ACT_SUM => 'sum',
     ACT_GET => 'get',
     ACT_DISCOVERY => 'discovery',
     CONTROLLER_VERSION_2 => 'v2',
     CONTROLLER_VERSION_3 => 'v3',
     CONTROLLER_VERSION_4 => 'v4',
     OBJ_USW => 'usw',
     OBJ_USW_PORT_TABLE => 'usw_port_table',
     OBJ_UAP_VAP_TABLE => 'uap_vap_table',
     OBJ_UPH => 'uph',
     OBJ_UAP => 'uap',
     OBJ_USG => 'usg',
     OBJ_WLAN => 'wlan',
     OBJ_USER => 'user',
     OBJ_SITE => 'site',
     OBJ_HEALTH => 'health',
#     OBJ_SYSINFO => 'sysinfo',
     DEBUG_LOW => 1,
     DEBUG_MID => 2,
     DEBUG_HIGH => 3,
     MAX_BUFFER_LEN => 65536,
     MAX_REQUEST_LEN => 256,
     KEY_ITEMS_NUM => 'items_num',
     TRUE => 1,
     FALSE => 0,
     BY_CMD => 1,
     BY_GET => 2,
     FETCH_NO_ERROR => 0,
     FETCH_OTHER_ERROR => 1,
     FETCH_LOGIN_ERROR => 2,
     TYPE_STRING => 1,
     TYPE_NUMBER => 2,
};

IO::Socket::SSL::set_default_context(new IO::Socket::SSL::SSL_Context(SSL_version => 'tlsv1', SSL_verify_mode => 0));

sub addToLLD;
sub fetchData;
sub fetchDataFromController;
sub getMetric;
sub handleCHLDSignal;
sub handleConnection;
sub handleTERMSignal;
sub makeLLD;
sub readConf;

my $options, my $res;
my $ck, my $wk;
foreach my $arg (@ARGV) {
  # try to take key from arg[i]
  ($ck) =  $arg =~ m/^-(.+)/;
  # key is '--version' ? Set flag && do nothing inside loop
  $options->{'version'} = TRUE, next if ($ck && ($ck eq '-version'));
  # key is --help - do the same
  $options->{'help'} = TRUE, next if ($ck && ($ck eq '-help'));
  # key is defined? Init hash item
  $options->{$ck}='' if ($ck);
  # not defined - store value to hash item with 'key' id.
  $options->{$wk}=$arg, next unless ($ck);
  # remember key for next loop, where it may be used for storing value to hash
  $wk=$ck;
}
            

if ($options->{'version'}) {
   print "\n",TOOL_NAME," v", TOOL_VERSION ,"\n";
   exit 0;
}
  
if ($options->{'help'}) {
   print "\n",TOOL_NAME," v", TOOL_VERSION, "\n\nusage: $0 [-C /path/to/config/file] [-D]",
          "\n\t-C\tpath to config file\n\t-D\trun in daemon mode\n\nAll other help on ", TOOL_HOMEPAGE, "\n\n";
   exit 0;
}

# take config filename from -"C"onfig option or from `default` const 
my $configFile=(defined ($options->{'C'})) ? $options->{'C'} : CONFIG_FILE_DEFAULT;

# if defined -"D"aemonMode - act like daemon
if (defined ($options->{'D'})) {
   my $pid = fork();
   exit() if $pid;
   die "[!] Couldn't act as daemon ($!)\n" unless defined($pid);
   # Link session to term
   POSIX::setsid() || die "[!] Can't start a new session ($!)";
}

my $globalConfig   = {}; 
# PreForked servers PID store
my $servers        = {};
# PreForked servers number
my $servers_num    = 0;

# Read config
readConf;
# Bind to addr:port
my $server = IO::Socket::INET->new(LocalAddr => $globalConfig->{'listenip'}, 
                                   LocalPort => $globalConfig->{'listenport'}, 
                                   Listen    => $globalConfig->{'maxclients'},
                                   Reuse     => 1,
                                   Type      => SOCK_STREAM,
                                   Proto     => 'tcp',) || die $@; 


# Assign subs to handle Signals
$SIG{INT} = $SIG{TERM} = \&handleINTSignal;
$SIG{HUP} = \&handleHUPSignal;
$SIG{CHLD} = \&handleCHLDSignal;
# And maintain the population.
while (1) {
    for (my $i = $servers_num; $i < $globalConfig->{'startservers'}; $i++) {
        # add several server instances if need
        makeServer();             
    }
    # wait for a signal (i.e., child's death)
    sleep;                          
}
exit;

############################################################################################################################
#
#                                                      Subroutines
#
############################################################################################################################
sub logMessage
  {
    return unless ($globalConfig->{'debuglevel'} >= $_[1]);
    print "[$$] ", strftime("%Y-%m-%d %H:%M:%S", localtime(time())), " $_[0]\n";
  }
#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
#
#  Handle CHLD signal
#    - Wait to terminate child process (kill zombie)
#    - Close listen port
#
#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
sub handleCHLDSignal {
    my $pid;
    while ( 0 < ($pid = waitpid(-1, WNOHANG))) {
          delete $servers->{$pid};
          $servers_num --;
    }
    $SIG{CHLD} = \&handleCHLDSignal;
}

sub handleHUPSignal {
    readConf;
}

#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
#
#  Handle TERM signal
#    - Set global flag, which using for main loop exiting
#    - Close listen port
#
#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
sub handleINTSignal {
    local($SIG{CHLD}) = 'IGNORE';   # we're going to kill our children
    kill 'INT' => keys %{$servers};
    exit;                           # clean up with dignity
}

#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
#
#  Make new server with PreFork engine
#    - Fork new server process
#    - Accept and handle connection from IO::SOCket queue
#
#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
sub makeServer {
    my $pid;
    my $sigset;
    # make copy of global config to stop change $_[0] by fork's copy-write procedure
   
    # block signal for fork
    $sigset = POSIX::SigSet->new(SIGINT);
    sigprocmask(SIG_BLOCK, $sigset) or die "[!] Can't block SIGINT for fork: $!\n";

    # if $pid is undefined - fork creating error caused
    die "[!] fork: $!" unless defined ($pid = fork);
    
    if ($pid) {
        # Parent records the child's birth and returns.
        sigprocmask(SIG_UNBLOCK, $sigset) or die "[!] Can't unblock SIGINT for fork: $!\n";
        $servers->{$pid} = 1;
        $servers_num++;
        $globalConfig->{'pid'}=$pid;
        return;
    } else {
        #############################################    
        # Child can *not* return from this subroutine.
        #############################################    
        # make SIGINT kill us as it did before
        $SIG{INT} = 'DEFAULT';     

        # unblock signals
        sigprocmask(SIG_UNBLOCK, $sigset) or die "[!] Can't unblock SIGINT for fork: $!\n";

        my $serverConfig;
        # copy hash with globalConfig to serverConfig to prevent 'copy-on-write'.
        %{$serverConfig}=%{$globalConfig;};

        # init service keys
        # Level of dive (recursive call) for getMetric subroutine
        $serverConfig->{'dive_level'} = 0;
        # Max level to which getMetric is dived
        $serverConfig->{'max_depth'} = 0;
        # Data is downloaded instead readed from file
        $serverConfig->{'downloaded'} = FALSE;
        # LWP::UserAgent object, which must be saved between fetchData() calls
        $serverConfig->{'ua'} = undef;
        # JSON::XS object
        $serverConfig->{'jsonxs'} = JSON::XS->new->utf8;
        # -s option used sign
        $globalConfig->{'sitename_given'} = FALSE;

        # handle connections until we've reached MaxRequestsPerChild
        for (my $i=0; $i < $serverConfig->{'maxrequestsperchild'}; $i++) {
            my $client = $server->accept() or last;
            $client->autoflush(1);
            handleConnection($serverConfig, $client);
        }
        # tidy up gracefully and finish
    
        # this exit is VERY important, otherwise the child will become
        # a producer of more and more children, forking yourself into
        # process death.
        exit;
    }
}

#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
#
#  Handle incoming connection
#
#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
sub handleConnection {
    my $socket = $_[1];
    my @objJSON=();
    my $gC;
    my $buffer;
    my $buferLength;

    # copy serverConfig to localConfig for saving default values 
    %{$gC}=%{$_[0]};

    # read line from socket
    while (1) {
        $buffer=<$socket>;
#       my $bytes=sysread($socket, $buffer, MAX_REQUEST_LEN);
#       redo unless ($bytes < 0);
       last unless ($buffer);
       chomp ($buffer);
       logMessage("[.]\t\tIncoming line: '$buffer'", DEBUG_LOW);
       # split line to action, object type, sitename, key, id, cache_timeout (need to add user name, user password, controller version ?)
       my ($opt_a, $opt_o, $opt_s, $opt_k, $opt_i, $opt_c)=split(",", $buffer);
       $buffer=undef;

       # fast validate object type  
       $gC->{'objecttype'}   = $opt_o ? $opt_o : $_[0]->{'objecttype'};
       unless ($gC->{'fetch_rules'}->{$opt_o}) {
           $buffer="[!] No object type $gC->{'objecttype'} supported";
           logMessage($buffer, DEBUG_LOW);
           next;
       }
       # fast check action need too
       # ...........
   
       # Rewrite default values (taken from globalConfig) by command line arguments
       $gC->{'action'}          = $opt_a ? $opt_a : $_[0]->{'action'};
       $gC->{'key'}             = $opt_k ? $opt_k : '';

       # opt_s not '' (virtual -s option used) -> use given sitename. Otherwise use 'default'
       $gC->{'sitename'}        = $opt_s ? $opt_s : $_[0]->{'default_sitename'};
       $gC->{'sitename_given'}  = $opt_s ? TRUE : FALSE;

       # if opt_c given, but = 0 - "$opt_k ?" is false and $gC->{'cachemaxage'} take default value;
       $gC->{'cachemaxage'}     = defined($opt_c) ? $opt_c+0 : $_[0]->{'cachemaxage'};

       $gC->{'id'} = $gC->{'mac'} = '';
       # test for $opt_i is MAC or ID
       if ($opt_i) {
          $_=uc($opt_i);
          if ( /^([0-9A-Z]{2}[:-]){5}([0-9A-Z]{2})$/ ) {
             # is MAC
             $gC->{'mac'} = $opt_i;
          } else {
             # is ID
             $gC->{'id'} = $opt_i;
          }
       }

       # flag for LLD routine
       if ($gC->{'action'} eq ACT_DISCOVERY) {
          # Call sub for made LLD-like JSON
          logMessage("[*] LLD requested", DEBUG_LOW);
          makeLLD($gC, $buffer);
#          fetchData($gC, $gC->{'sitename'}, $gC->{'objecttype'}, $gC->{'id'}, \@objJSON);
          next;
       }

       if ($gC->{'key'}) {
          # Key is given - need to get metric. 
          # if $globalConfig->{'id'} is exist then metric of this object has returned. 
          # If not - calculate $globalConfig->{'action'} for all items in objects list (all object of type = 'object name', for example - all 'uap'
          # load JSON data & get metric
          logMessage("[*] Key given: $gC->{'key'}", DEBUG_LOW);
          if (! fetchData($gC, $gC->{'sitename'}, $gC->{'objecttype'}, $gC->{'id'}, \@objJSON)) {
             $buffer="[!] FetchData error";
             logMessage($buffer, DEBUG_LOW);
             next;
          }
          getMetric($gC, \@objJSON, $gC->{'key'}, $buffer);
          @objJSON=();
       }
  } continue {
       # Value could be null-type (undef in Perl). If need to replace null to other char - {'null_char'} must be defined. On default $gC->{'null_char'} is ''
       $buffer = $gC->{'null_char'} unless defined($buffer);
       $buferLength = length($buffer);
       # MAX_BUFFER_LEN - Zabbix buffer length. Sending more bytes have no sense.
       if ( MAX_BUFFER_LEN <= $buferLength) {
           $buferLength = MAX_BUFFER_LEN-1;
           $buffer = substr($buffer, 0, $buferLength);
       }
#       $buffer .= "\n";
       # Push buffer to socket
       print $socket "$buffer\n";
#       syswrite($socket, $buffer, $buferLength);    
  }

  # Logout need if logging in before (in fetchData() sub) completed
  logMessage("[*] Logout from UniFi controller", DEBUG_LOW), $gC->{'ua'}->get($gC->{'logout_path'}) if (defined($gC->{'ua'}));
  return TRUE;
}
    
#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
#
#  Recursively go through the key and take/form value of metric
#
#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
sub getMetric {
    # $_[0] - GlobalConfig
    # $_[1] - array/hash with info
    # $_[2] - key
    # $_[3] - result

    # dive to...
    $_[0]->{'dive_level'}++;

    logMessage("[+] ($_[0]->{'dive_level'}) getMetric() started", DEBUG_LOW);
    my $key=$_[2], my $objList;

    logMessage("[>]\t args: key: '$_[2]', action: '$_[0]->{'action'}'", DEBUG_LOW);
#    logMessage("[>]\t incoming object info:'\n\t".(Dumper $_[1]), DEBUG_HIGH);

    # correcting maxDepth for ACT_COUNT operation
    $_[0]->{'max_depth'} = ($_[0]->{'dive_level'} > $_[0]->{'max_depth'}) ? $_[0]->{'dive_level'} : $_[0]->{'max_depth'};
    
    # Checking for type of $_[1]. 
    # if $_[1] is array - need to explore any element
    if (ref($_[1]) eq 'ARRAY') {
       my $paramValue;
       $objList=@{$_[1]};
       logMessage("[.]\t\t Array with $objList objects detected", DEBUG_MID);

       # if metric ask "how much items (AP's for example) in all" - just return array size (previously calculated in $objList) and do nothing more
       if ($key eq KEY_ITEMS_NUM) { 
          $_[3]=$objList; 
       } else {
          $_[3]=0; 
          logMessage("[.]\t\t Taking value from all sections", DEBUG_MID);
          # Take each element of array
          for (my $i=0; $i < $objList; $i++ ) {
            # Init $paramValue for right actions doing
            $paramValue=undef;
            # Do recursively calling getMetric func for each element 
            # that is bad strategy, because sub calling anytime without tesing of key existiense, but that testing can be slower, that sub recalling 
            #                                                                                                                    (if filter-key used)
            getMetric($_[0], $_[1][$i], $key, $paramValue); 
            logMessage("[.]\t\t paramValue: '$paramValue'", DEBUG_HIGH) if (defined($paramValue));


            # Otherwise - do something line sum or count
            if (defined($paramValue)) {
               logMessage("[.]\t\t act #$_[0]->{'action'}", DEBUG_MID);

               # With 'get' action jump out from loop with first recieved value
               $_[3]=$paramValue, last if ($_[0]->{'action'} eq ACT_GET);

               # !!! need to fix trying sum of not numeric values
               # With 'sum' - grow $result
               if (ACT_SUM eq $_[0]->{'action'}) { 
                  $_[3]+=$paramValue; 
               } elsif (ACT_COUNT eq $_[0]->{'action'} || ACT_PERCENT eq $_[0]->{'action'}) {
                  # may be wrong algo :(
                  # workaround for correct counting with deep diving
                  # With 'count' we must count keys in objects, that placed only on last level
                  # in other case $result will be incremented by $paramValue (which is number of keys inside objects on last level table)
                  #  
                  #  **************** NEED AN EXAMPLE OF REQUEST TO REPRODUCE BUG ****************
                  #
#                  if (($_[0]->{'max_depth'}-$_[0]->{'dive_level'}) < 2 ) {
#                     $_[3]++; 
#                  } else {
                     $_[3]+=$paramValue; 
#                  }
              }
            }
            logMessage("[.]\t\t Value: '$paramValue', result: '$_[3]'", DEBUG_MID) if (defined($paramValue));
          } #foreach 
       }
   } else { # if (ref($_[1]) eq 'ARRAY') {
      # it is not array (list of objects) - it's one object (hash)
      logMessage("[.]\t\t Just one object detected", DEBUG_MID);
      my $tableName, my $matchCount=0, my $filterCount=0;
      ($tableName, $key) = split(/[.]/, $key, 2);

      # if key is not defined after split (no comma in key) that mean no table name exist in incoming key 
      # and key is first and only one part of splitted data
      if (! defined($key)) { 
         $key = $tableName; undef $tableName;
      } else {
         my $fStr;
         # check for [filterkey=value&filterkey=value&...] construction in tableName. If that exist - key filter feature will enabled
         #($fStr) = $tableName =~ m/^\[([\w]+=.+&{0,1})+\]/;
         # regexp matched string placed into $1 and $1 listed as $fStr
         ($fStr) = $tableName =~ m/^\[(.+)\]/;

         # Test filter keys
         if ($fStr) {
           #
           # [key_1=val_1&key_2=val_2&key_3=val_3|key_4=val_4]
           #
           # need to tokenize $fStr for "&" or "|": ...([&|])(expr)
           # Then if &expr = TRUE => $filterCount++, if |expr = TRUE $matchCount = $filterCount & last;
           #
           my @fData=split ('&', $fStr);
           logMessage("\t\t Matching object's keys...", DEBUG_MID);
           # run trought flter list
           for (my $i=0; $i < @fData; $i++) {
                my ($k, $v)=split ('=', $fData[$i]);
                # Key is not null?
                if (defined($k)) {
                   # if so - filter is defined
                   $filterCount++;
                   # Value is not null?
                   if (!defined($v)) {
                      # null -> just test JSON-key existience and increase match count
                      $matchCount++ if (exists($_[1]->{$k}));
                   } else {
                      # not null -> test JSON-key's value and increase match count
                      $matchCount++ if (defined($_[1]->{$k}) && ($_[1]->{$k} eq $v));
                   }
               }
           }
           undef $tableName;

         }
       }
       # Subtable could be not exist as 'vap_table' for UAPs which is powered off.
       # In this case $result must stay undefined for properly processed on previous dive level if subroutine is called recursively
       # Pass inside if no filter defined ($filterCount == $matchCount == 0) or all keys is matched
       if ($matchCount == $filterCount) {
          logMessage("[.]\t\t Object is good", DEBUG_MID);
          if ($tableName && defined($_[1]->{$tableName})) {
             # if subkey was detected (tablename is given an exist) - do recursively calling getMetric func with subtable and subkey and get value from it
             logMessage("[.]\t\t It's object. Go inside", DEBUG_MID);
             getMetric($_[0], $_[1]->{$tableName}, $key, $_[3]); 
          } elsif (exists($_[1]->{$key})) {
             # Otherwise - just return value for given key
             logMessage("[.]\t\t It's key. Take value... '$_[1]->{$key}'", DEBUG_MID);
             if (ACT_COUNT eq $_[0]->{'action'} || ACT_PERCENT eq $_[0]->{'action'}) {
                $_[3]=1;
             } else {
                $_[3]=$_[1]->{$key};
             }
          } else {
             logMessage("[.]\t\t No key or table exist :(", DEBUG_MID);
          }
       } # if ($matchCount == $filterCount)
   } # if (ref($_[1]) eq 'ARRAY') ... else ...

  logMessage("[<] ($_[0]->{'dive_level'}) getMetric() finished /$_[0]->{'max_depth'}/", DEBUG_LOW);
  logMessage("[<] result: ($_[3])", DEBUG_LOW) if (defined($_[3]));

  #float up...
  $_[0]->{'dive_level'}--;

  # sprintf used for round up to xx.yy
  $_[3] = sprintf("%.2f", ((0 == $objList) ? 0 : ($_[3]/($objList/100)))) if ((ACT_PERCENT eq $_[0]->{'action'}) && (0 == $_[0]->{'dive_level'}));

  return TRUE;
}


#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
#
#  Fetch data from cache or call fetching from controller. Renew cache files.
#
#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
sub fetchData {
   # $_[0] - $GlobalConfig
   # $_[1] - sitename
   # $_[2] - object type
   # $_[3] - obj id
   # $_[4] - jsonData object ref
   logMessage("[+] fetchData() started", DEBUG_LOW);
   logMessage("[>]\t args: object type: '$_[0]->{'objecttype'}'", DEBUG_MID);
   logMessage("[>]\t id: '$_[3]'", DEBUG_MID) if ($_[3]);
   logMessage("[>]\t mac: '$_[0]->{'mac'}'", DEBUG_MID) if ($_[0]->{'mac'});
   my ($fh, $jsonData, $objPath),
   my $needReadCache=TRUE;

   $objPath  = $_[0]->{'api_path'} . ($_[0]->{'fetch_rules'}->{$_[2]}->{'excl_sitename'} ? '' : "/s/$_[1]") . "/$_[0]->{'fetch_rules'}->{$_[2]}->{'path'}";
   # if MAC is given with command-line option -  RapidWay for Controller v4 is allowed, short_way is tested for non-device objects workaround
   $objPath.="/$_[0]->{'mac'}" if (($_[0]->{'unifiversion'} eq CONTROLLER_VERSION_4) && $_[0]->{'mac'} && $_[0]->{'fetch_rules'}->{$_[2]}->{'short_way'});
   logMessage("[.]\t\t Object path: '$objPath'", DEBUG_MID);

   ################################################## Take JSON  ##################################################

   # If CacheMaxAge = 0 - do not try to read/update cache - fetch data from controller
   if (0 == $_[0]->{'cachemaxage'}) {
      logMessage("[.]\t\t No read/update cache because CacheMaxAge = 0", DEBUG_MID);
      fetchDataFromController($_[0], $objPath, $jsonData) or logMessage("[!] Can't fetch data from controller, stop", DEBUG_LOW), return FALSE;
   } else {
      # Change all [:/.] to _ to make correct filename
      my $cacheFileName;
      ($cacheFileName = $objPath) =~ tr/\/\:\./_/, 
      $cacheFileName = $_[0]->{'cachedir'} .'/'. $cacheFileName;
      my $cacheFileMTime=(stat($cacheFileName))[9];
      # cache file unexist (mtime is undef) or regular?
      ($cacheFileMTime && (!-f $cacheFileName)) and logMessage("[!] Can't handle '$cacheFileName' through its not regular file, stop.", DEBUG_LOW), return FALSE;
      # cache is expired if: unexist (mtime is undefined) OR (file exist (mtime is defined) AND its have old age) 
      #                                                   OR have Zero size (opened, but not filled or closed with error)
      my $cacheExpire=(((! defined($cacheFileMTime)) || defined($cacheFileMTime) && (($cacheFileMTime+$_[0]->{'cachemaxage'}) < time())) ||  -z $cacheFileName) ;

      if ($cacheExpire) {
         # Cache expire - need to update
         logMessage("[.]\t\t Cache expire or not found. Renew...", DEBUG_MID);
         my $tmpCacheFileName = $cacheFileName . ".tmp";
         # Temporary cache filename point to non regular file? If so - die to avoid problem with write or link/unlink operations
         # $_ not work
         ((-e $tmpCacheFileName) && (!-f $tmpCacheFileName)) and logMessage("[!] Can't handle '$tmpCacheFileName' through its not regular file, stop.", DEBUG_LOW), return FALSE;
         logMessage("[.]\t\t Temporary cache file='$tmpCacheFileName'", DEBUG_MID);
         open ($fh, ">", $tmpCacheFileName) or logMessage("[!] Can't open '$tmpCacheFileName' ($!), stop.", DEBUG_LOW), return FALSE;
         # try to lock temporary cache file and no wait for able locking.
         # LOCK_EX | LOCK_NB
         if (flock ($fh, 2 | 4)) {
            # if Proxy could lock temporary file, it...
            chmod (0666, $fh);
            # ...fetch new data from controller...
            fetchDataFromController($_[0], $objPath, $jsonData) or logMessage("[!] Can't fetch data from controller, stop", DEBUG_LOW), close ($fh), return FALSE;
            # unbuffered write it to temp file..
            syswrite ($fh, $_[0]->{'jsonxs'}->encode($jsonData));
            # Now unlink old cache filedata from cache filename 
            # All processes, who already read data - do not stop and successfully completed reading
            unlink ($cacheFileName);
            # Link name of cache file to temp file. File will be have two link - to cache and to temporary cache filenames. 
            # New run down processes can get access to data by cache filename
            link($tmpCacheFileName, $cacheFileName) or logMessage("[!] Presumably no rights to unlink '$cacheFileName' file ($!). Try to delete it ", DEBUG_LOW), return FALSE;
            # Unlink temp filename from file. 
            # Process, that open temporary cache file can do something with filedata while file not closed
            unlink($tmpCacheFileName) or logMessage("[!] '$tmpCacheFileName' unlink error ($!), stop", DEBUG_LOW), return FALSE;
            # Close temporary file. close() unlock filehandle.
            #close($fh) or logMessage("[!] Can't close locked temporary cache file '$tmpCacheFileName' ($!), stop", DEBUG_LOW), return FALSE; 
            # No cache read from file need
           $needReadCache=FALSE;
        } 
        close ($fh) or logMessage("[!] Can't close temporary cache file '$tmpCacheFileName' ($!), stop", DEBUG_LOW), return FALSE;
      } # if ($cacheExpire)

      # if need load data from cache file
      if ($needReadCache) {
       # open file
       open($fh, "<:mmap", $cacheFileName) or logMessage("[!] Can't open '$cacheFileName' ($!), stop.", DEBUG_LOW), return FALSE;
       # read data from file
       $jsonData=$_[0]->{'jsonxs'}->decode(<$fh>);
       # close cache
       close($fh) or logMessage( "[!] Can't close cache file ($!), stop.", DEBUG_LOW), return FALSE;
    }
  } # if (0 == $_[0]->{'cachemaxage'})

  ################################################## JSON processing ##################################################
  # push() to $_[4] or delete() from $jsonData? If delete() just clean refs - no memory will reserved to new array.
  # UBNT Phones store ID into 'device_id' key (?)
  my $idKey = ($_[2] eq OBJ_UPH) ? 'device_id' : '_id'; 

  # Walk trought JSON array
  for (my $i=0; $i < @{$jsonData}; $i++) {
     # Object have ID...
     if ($_[3]) {
       #  ...and its required object? If so push - object to global @objJSON and jump out from the loop.
#       print "id: @{$jsonData}[$i]->{$idKey} \n";
       $_[4][0]=@{$jsonData}[$i], last if (@{$jsonData}[$i]->{$idKey} eq $_[3]);
     } else {
       # otherwise
       push (@{$_[4]}, @{$jsonData}[$i]) if (!exists(@{$jsonData}[$i]->{'type'}) || (@{$jsonData}[$i]->{'type'} eq $_[2]));
     }
   } # for each jsonData

#   logMessage("[<]\t Fetched data:\n\t".(Dumper $_[4]), DEBUG_HIGH);
   
   logMessage("[-] fetchData() finished", DEBUG_LOW);
   return TRUE;
}

#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
#
#  Fetch data from from controller.
#
#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
sub fetchDataFromController {
   # $_[0] - GlobalConfig
   # $_[1] - object path
   # $_[2] - jsonData object ref
   my $response, my $fetchType=$_[0]->{'fetch_rules'}->{$_[0]->{'objecttype'}}->{'method'},
   my $fetchCmd=$_[0]->{'fetch_rules'}->{$_[0]->{'objecttype'}}->{'cmd'}, my $errorCode;

   logMessage("[+] fetchDataFromController() started", DEBUG_LOW);
   logMessage("[>]\t args: object path: '$_[1]'", DEBUG_LOW);

   # HTTP UserAgent init
   # Set SSL_verify_mode=off to login without certificate manipulation
   $_[0]->{'ua'} = LWP::UserAgent-> new('cookie_jar' => {}, 'agent' => TOOL_NAME."/".TOOL_VERSION." (perl engine)",
                                        'timeout' => $_[0]->{'unifitimeout'}, 'ssl_opts' => {'verify_hostname' => 0}) unless ($_[0]->{'ua'});
   ################################################## Logging in  ##################################################
   # Check to 'still logged' state
   # ->head() not work
   $response=$_[0]->{'ua'}->get("$_[0]->{'api_path'}/self");
   # FETCH_OTHER_ERROR = is_error == TRUE (1), FETCH_NO_ERROR = is_error == FALSE (0)
   # FETCH_OTHER_ERROR stop work if get() haven't success && no error 401 (login required). For example - error 500 (connect refused)
   $errorCode=$response->is_error;
   # not logged?
   if ($response->code eq '401') {
        # logging in
        logMessage("[.]\t\tTry to log in into controller...", DEBUG_LOW);
        $response=$_[0]->{'ua'}->post($_[0]->{'login_path'}, 'Content_type' => "application/$_[0]->{'login_type'}",'Content' => $_[0]->{'login_data'});
#        logMessage("[>>]\t\t HTTP respose:\n\t".(Dumper $response), DEBUG_HIGH);
        my $rc=$response->code;
        $errorCode=$response->is_error;
        if ($_[0]->{'unifiversion'} eq CONTROLLER_VERSION_4) {
           # v4 return 'Bad request' (code 400) on wrong auth
           # v4 return 'OK' (code 200) on success login
           ($rc eq '400') and $errorCode=FETCH_LOGIN_ERROR;
        } elsif (($_[0]->{'unifiversion'} eq CONTROLLER_VERSION_3) || ($_[0]->{'unifiversion'} eq CONTROLLER_VERSION_2)) {
           # v3 return 'OK' (code 200) on wrong auth
           ($rc eq '200') and $errorCode=FETCH_LOGIN_ERROR;
           # v3 return 'Redirect' (code 302) on success login and must die only if code<>302
           ($rc eq '302') and $errorCode=FETCH_NO_ERROR;
        }
    }
    ($errorCode == FETCH_LOGIN_ERROR) and logMessage("[!] Login error - wrong auth data, stop", DEBUG_LOW), return FALSE;
    ($errorCode == FETCH_OTHER_ERROR) and logMessage("[!] Comminication error: '".($response->status_line)."', stop.\n", DEBUG_LOW), return FALSE;

    logMessage("[.]\t\tLogin successfull", DEBUG_LOW);

   ################################################## Fetch data from controller  ##################################################

   if (BY_CMD == $fetchType) {
      logMessage("[.]\t\t Fetch data with CMD method: '$fetchCmd'", DEBUG_MID);
      $response=$_[0]->{'ua'}->post($_[1], 'Content_type' => 'application/json', 'Content' => $fetchCmd);
   } else { #(BY_GET == $fetchType)
      logMessage("[.]\t\t Fetch data with GET method from: '$_[1]'", DEBUG_MID);
      $response=$_[0]->{'ua'}->get($_[1]);
   }

   ($response->is_error == FETCH_OTHER_ERROR) and logMessage("[!] Comminication error while fetch data from controller: '".($response->status_line)."', stop.\n", DEBUG_LOW), return FALSE;
   
   # logMessage("[>>]\t\t Fetched data:\n\t".(Dumper $response->decoded_content), DEBUG_HIGH);
#   $_[2]=$_[0]->{'jsonxs'}->decode($response->decoded_content);
   $_[2]=$_[0]->{'jsonxs'}->decode(${$response->content_ref()});


   # server answer is ok ?
   (($_[2]->{'meta'}->{'rc'} ne 'ok') && (defined($_[2]->{'meta'}->{'msg'}))) and  logMessage("[!] UniFi controller reply is not OK: '$_[2]->{'meta'}->{'msg'}', stop.", DEBUG_LOW);
   $_[2]=$_[2]->{'data'};
#   logMessage("[<]\t decoded data:\n\t".(Dumper $_[2]), DEBUG_HIGH);
   $_[0]->{'downloaded'}=TRUE;
   return TRUE;
}

#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
#
#  Generate LLD-like JSON using fetched data
#
#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
sub makeLLD {
    # $_[0] - $globalConfig
    # $_[1] - result
    #
    #  addToLLD() must be called with parentObj (siteObj now);
    #
    #
    logMessage("[+] makeLLD() started", DEBUG_LOW);
    logMessage("[>]\t args: object type: '$_[0]->{'objecttype'}'", DEBUG_MID);
    my $jsonObj, my $lldResponse, my $lldPiece; my $siteList=(), my $objList =(),
    my $givenObjType=$_[0]->{'objecttype'}, my $siteWalking=FALSE, my $siteObj;

    $siteWalking=TRUE if (defined($_[0]->{'fetch_rules'}->{&OBJ_SITE}) && (!$_[0]->{'sitename_given'}));
    
    # return right JSON on error or not?
    # $_[1]="{\"data\":[]}";
    $_[1]="{\"data\":error on lld generate}";

    # if no OBJ_SITE in fetch_rules - it's v2 controller, which not support sites
    if ($_[0]->{'fetch_rules'}->{&OBJ_SITE}) {
        # Get site list
        fetchData($_[0], $_[0]->{'sitename'}, OBJ_SITE, '', $siteList);# or return FALSE;
    } else {
        # or made fake site list
        $siteList=[{'name' => 'default'}];
    }

    if (OBJ_SITE eq $givenObjType) {
        addToLLD($_[0], undef, $siteList, $lldPiece) if ($siteList);
     } else {
        foreach my $siteObj (@{$siteList}) {
          my $parentObj={};
          # skip hidden site 'super', 0+ convert literal true/false to decimal
          next if (defined($siteObj->{'attr_hidden'}));
          # skip site, if '-s' option used and current site other, that given
          next if ($_[0]->{'sitename_given'} && ($_[0]->{'sitename'} ne $siteObj->{'name'}));
          logMessage("[.]\t\t Handle site: '$siteObj->{'name'}'", DEBUG_MID);
          # make parent object from siteObj for made right macroses in addToLLD() sub
          $parentObj={'type' => OBJ_SITE, 'data' => $siteObj};
          # Not nulled list causes duplicate LLD items
          $objList=();
          # Take objects from foreach'ed site
          fetchData($_[0], $siteObj->{'name'}, $givenObjType, $_[0]->{'id'}, $objList) or logMessage("[!] No data fetched from site '$siteObj->{'name'}', stop", DEBUG_MID), return FALSE;
          #   print Dumper $_[4];
          # if JSON contain only one array element with object
          if (defined($_[0]->{'id'}) && 'ARRAY' eq ref($objList) && 1 == @{$objList}) {
             # if given key exist inside this object and point to array too...
             if (exists(@{$objList}[0]->{$_[0]->{'key'}}) && 'ARRAY' eq ref(@{$objList}[0]->{$_[0]->{'key'}})) {
                # store parent object
                $parentObj={'type' => $givenObjType, 'data' => @{$objList}[0]};
                # use this nested array instead object
                $objList=@{$objList}[0]->{$_[0]->{'key'}};
             }
          }
          # Add its info to LLD-response 
#          logMessage("[.]\t\t Objects list:\n\t".(Dumper $objList), DEBUG_HIGH);
          addToLLD($_[0], $parentObj, $objList, $lldPiece) if ($objList);
        } #foreach
     }    
    defined($lldPiece) or logMessage("[!] No data found for object $givenObjType (may be wrong site name), stop", DEBUG_MID), return FALSE;
    # link LLD to {'data'} key
    undef($_[1]),
     $_[1]->{'data'} = $lldPiece,
    # make JSON
    $_[1]=$_[0]->{'jsonxs'}->encode($_[1]);
#    logMessage("[<]\t Generated LLD:\n\t".(Dumper $_[1]), DEBUG_HIGH);
    logMessage("[-] makeLLD() finished", DEBUG_LOW);
    return TRUE;
}

#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
#
#  Add a piece to exists LLD-like JSON 
#
#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
sub addToLLD {
    # $_[0] - $globalConfig
    # $_[1] - Parent object
    # $_[2] - Incoming objects list
    # $_[3] - Outgoing objects list

    # remap object type: add key to type for right select and add macroses
    my $givenObjType  = $_[0]->{'objecttype'}.($_[0]->{'key'} ? "_$_[0]->{'key'}" : '');
    my $parentObjType = $_[1]->{'type'}, my $parentObjData = $_[1]->{'data'} if (defined($_[1]));

    logMessage("[+] addToLLD() started", DEBUG_LOW); logMessage("[>]\t args: object type: '$_[0]->{'objecttype'}'", DEBUG_MID); 
#    logMessage("[>]\t       site name: '$_[1]->{'name'}'", DEBUG_MID) if ($_[1]->{'name'});
    # $o - outgoing object's array element pointer, init as length of that array to append elements to the end
    my $o = $_[3] ? @{$_[3]} : 0;
    foreach (@{$_[2]}) {
      # skip hidden 'super' site with OBJ_SITE
      next if ($_->{'attr_hidden'});
      # $_[1] contain parent's data and its may be undefined if script uses with v2 controller or while generating LLD for OBJ_SITE  
      # if defined $_[0]->{'key'})  - discovery for subtable must be maded
      if (defined($_[1])) {
         # analyze parent & add some fields
         if (OBJ_SITE eq $parentObjType) {
            $_[3][$o]->{'{#SITEID}'}    = "$parentObjData->{'_id'}";
            $_[3][$o]->{'{#SITENAME}'}  = "$parentObjData->{'name'}";
            # In v3 'desc' key is not exist, and site desc == name
            $_[3][$o]->{'{#SITEDESC}'}  = $_[1]->{'desc'} ? "$parentObjData->{'desc'}" : "$parentObjData->{'name'}";
         } elsif (OBJ_USW eq $parentObjType) {
            $_[3][$o]->{'{#USWID}'}    = "$parentObjData->{'_id'}";
            $_[3][$o]->{'{#USWNAME}'}  = "$parentObjData->{'name'}";
            $_[3][$o]->{'{#USWMAC}'}    = "$parentObjData->{'mac'}";
         } elsif (OBJ_UAP eq $parentObjType) {
            $_[3][$o]->{'{#UAPID}'}    = "$parentObjData->{'_id'}";
            $_[3][$o]->{'{#UAPNAME}'}  = "$parentObjData->{'name'}";
            $_[3][$o]->{'{#UAPMAC}'}   = "$parentObjData->{'mac'}";
         }
      }

      #  add common fields
      $_[3][$o]->{'{#NAME}'}         = "$_->{'name'}"     if (exists($_->{'name'}));
      $_[3][$o]->{'{#ID}'}           = "$_->{'_id'}"      if (exists($_->{'_id'}));
      $_[3][$o]->{'{#IP}'}           = "$_->{'ip'}"       if (exists($_->{'ip'}));
      $_[3][$o]->{'{#MAC}'}          = "$_->{'mac'}"      if (exists($_->{'mac'}));
      # state of object: 0 - off, 1 - on
      $_[3][$o]->{'{#STATE}'}        = "$_->{'state'}"    if (exists($_->{'state'}));
      $_[3][$o]->{'{#ADOPTED}'}      = "$_->{'adopted'}"  if (exists($_->{'adopted'}));

      # add object specific fields
      if      (OBJ_WLAN eq $givenObjType ) {
         # is_guest key could be not exist with 'user' network on v3 
         $_[3][$o]->{'{#ISGUEST}'}   = "$_->{'is_guest'}" if (exists($_->{'is_guest'}));
      } elsif (OBJ_USER eq $givenObjType) {
         # sometime {hostname} may be null. UniFi controller replace that hostnames by {'mac'}
         $_[3][$o]->{'{#NAME}'}      = $_->{'hostname'} ? "$_->{'hostname'}" : "$_->{'mac'}";
      } elsif (OBJ_UPH eq $givenObjType) {
         $_[3][$o]->{'{#ID}'}        = "$_->{'device_id'}";
      } elsif (OBJ_SITE eq $givenObjType) {
         # In v3 'desc' key is not exist, and site desc == name
         $_[3][$o]->{'{#DESC}'} = $_->{'desc'} ? "$_->{'desc'}" : "$_->{'name'}";
      } elsif (OBJ_UAP_VAP_TABLE eq $givenObjType) {
         $_[3][$o]->{'{#UP}'}        = "$_->{'up'}";
         $_[3][$o]->{'{#USAGE}'}     = "$_->{'usage'}";
         $_[3][$o]->{'{#RADIO}'}     = "$_->{'radio'}";
         $_[3][$o]->{'{#ISWEP}'}     = "$_->{'is_wep'}";
         $_[3][$o]->{'{#ISGUEST}'}   = "$_->{'is_guest'}";
      } elsif (OBJ_USW_PORT_TABLE eq $givenObjType) {
         $_[3][$o]->{'{#PORTIDX}'}   = "$_->{'port_idx'}";
         $_[3][$o]->{'{#MEDIA}'}     = "$_->{'media'}";
         $_[3][$o]->{'{#UP}'}        = "$_->{'up'}";
         $_[3][$o]->{'{#PORTPOE}'}   = "$_->{'port_poe'}";
#      } elsif ($givenObjType eq OBJ_HEALTH) {
#         $_[3][$o]->{'{#SUBSYSTEM}'} = $_->{'subsystem'};
#      } elsif (OBJ_UAP eq $givenObjType) {
#         ;
#      } elsif ($givenObjType eq OBJ_USG || $givenObjType eq OBJ_USW) {
#        ;
      }
     $o++;
    }
#    logMessage("[<]\t Generated LLD piece:\n\t".(Dumper $_[3]), DEBUG_HIGH);
#    logMessage("[-] addToLLD() finished", DEBUG_LOW);
    return TRUE;
}

#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
#
#  Read config file
#    - Read param values from file
#    - If they valid - store its into #globalConfig
#
#  ! all incoming variables is global
#
#*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/*/
sub readConf {

#############
my   $configDefs = {
        'cachedir'                 => [TYPE_STRING, '/dev/shm'],
        'cachemaxage'              => [TYPE_NUMBER, 60],
        'debuglevel'               => [TYPE_NUMBER, FALSE],

        'listenip'                 => [TYPE_STRING, 'localhost'],
        'listenport'               => [TYPE_NUMBER, 8448],
        'startservers'             => [TYPE_NUMBER, 3],
        'maxclients'               => [TYPE_NUMBER, 10],
        'maxrequestsperchild'      => [TYPE_NUMBER, 1024],

        'action'                   => [TYPE_STRING, ACT_DISCOVERY],
        'objecttype'               => [TYPE_STRING, OBJ_WLAN],
        'sitename'                 => [TYPE_STRING, 'default'],
        'unifilocation'            => [TYPE_STRING, '127.0.0.1:8443'],
        'unifiversion'             => [TYPE_STRING, CONTROLLER_VERSION_4],
        'unifiuser'                => [TYPE_STRING, 'admin'],
        'unifipass'                => [TYPE_STRING, 'ubnt'],
        'unifitimeout'             => [TYPE_NUMBER, 60],

        'nullchar'                 => [TYPE_STRING, ''],
      
    };

    my   $configVals;
    if (open(my $fh, $configFile)) {
       # Read values of globala params from config file
       while(<$fh>){
         # skip comments
         $_ =~ /^($|#)/ && next;
         # skip empty lines
         chomp or next;
         # ' key =   value ' => 'key' & 'value'
         my ($k, $v) = $_ =~ m/\s*(\w+)\s*=\s*(\S*)\s*/;
         $configVals->{lc($k)}=$v;
      }
      close($fh);
    }

    # copy readed values to global config and cast its if need    
    foreach (keys $configDefs) {
        $globalConfig->{$_} = $configVals->{$_} ? $configVals->{$_} : $configDefs->{$_}[1];
        $globalConfig->{$_} +=0 if (TYPE_NUMBER  == $configDefs->{$_}[0]);
    }

   (-e $globalConfig->{'cachedir'}) or die "[!] Cache dir not found: '$globalConfig->{'cachedir'}'\n";
   (-d $globalConfig->{'cachedir'}) or die "[!] Cache dir not dir: '$globalConfig->{'cachedir'}'\n";

   # Sitename which replaced {'sitename'} if '-s' option not used
   $globalConfig->{'default_sitename'} = 'default';
   $globalConfig->{'api_path'}      = "$globalConfig->{'unifilocation'}/api";
   $globalConfig->{'login_path'}    = "$globalConfig->{'unifilocation'}/login";
   $globalConfig->{'logout_path'}   = "$globalConfig->{'unifilocation'}/logout";
   $globalConfig->{'login_data'}    = "username=$globalConfig->{'unifiuser'}&password=$globalConfig->{'unifipass'}&login=login";
   $globalConfig->{'login_type'}    = 'x-www-form-urlencoded';

    # Set controller version specific data
    if ($globalConfig->{'unifiversion'} eq CONTROLLER_VERSION_4) {
       $globalConfig->{'login_path'}    = "$globalConfig->{'unifilocation'}/api/login";
       $globalConfig->{'login_data'} = "{\"username\":\"$globalConfig->{'unifiuser'}\",\"password\":\"$globalConfig->{'unifipass'}\"}",
       $globalConfig->{'login_type'} = 'json',
       # Data fetch rules.
       # BY_GET mean that data fetched by HTTP GET from .../api/[s/<site>/]{'path'} operation.
       #    [s/<site>/] must be excluded from path if {'excl_sitename'} is defined
       # BY_CMD say that data fetched by HTTP POST {'cmd'} to .../api/[s/<site>/]{'path'}
       #
       $globalConfig->{'fetch_rules'} = {
       # `&` let use value of constant, otherwise we have 'OBJ_UAP' => {...} instead 'uap' => {...}
       #     &OBJ_HEALTH => {'method' => BY_GET, 'path' => 'stat/health'},
          &OBJ_SITE     => {'method' => BY_GET, 'path' => 'self/sites', 'excl_sitename' => TRUE},
          &OBJ_UAP      => {'method' => BY_GET, 'path' => 'stat/device', 'short_way' => TRUE},
          &OBJ_UPH      => {'method' => BY_GET, 'path' => 'stat/device', 'short_way' => TRUE},
          &OBJ_USG      => {'method' => BY_GET, 'path' => 'stat/device', 'short_way' => TRUE},
          &OBJ_USW      => {'method' => BY_GET, 'path' => 'stat/device', 'short_way' => TRUE},
#          &OBJ_USW_PORT => {'method' => BY_GET, 'path' => 'stat/device', 'short_way' => TRUE},
          &OBJ_USER     => {'method' => BY_GET, 'path' => 'stat/sta'},
          &OBJ_WLAN     => {'method' => BY_GET, 'path' => 'list/wlanconf'}
       };
    } elsif ($globalConfig->{'unifiversion'} eq CONTROLLER_VERSION_3) {
       $globalConfig->{'fetch_rules'} = {
          # `&` let use value of constant, otherwise we have 'OBJ_UAP' => {...} instead 'uap' => {...}
          &OBJ_SITE => {'method' => BY_CMD, 'path' => 'cmd/sitemgr', 'cmd' => '{"cmd":"get-sites"}'},
          #&OBJ_SYSINFO => {'method' => BY_GET, 'path' => 'stat/sysinfo'},
          &OBJ_UAP  => {'method' => BY_GET, 'path' => 'stat/device'},
          &OBJ_USER => {'method' => BY_GET, 'path' => 'stat/sta'},
          &OBJ_WLAN => {'method' => BY_GET, 'path' => 'list/wlanconf'}
       };
    } elsif ($globalConfig->{'unifiversion'} eq CONTROLLER_VERSION_2) {
       $globalConfig->{'fetch_rules'} = {
       # `&` let use value of constant, otherwise we have 'OBJ_UAP' => {...} instead 'uap' => {...}
          &OBJ_UAP  => {'method' => BY_GET, 'path' => 'stat/device', 'excl_sitename' => TRUE},
          &OBJ_WLAN => {'method' => BY_GET, 'path' => 'list/wlanconf', 'excl_sitename' => TRUE},
          &OBJ_USER => {'method' => BY_GET, 'path' => 'stat/sta', 'excl_sitename' => TRUE}
       };
    } else {
       return "[!] Version of controller is unknown: '$globalConfig->{'unifiversion'}, stop";
    }
   return TRUE;
}
