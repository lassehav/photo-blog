#!/usr/bin/perl -w

use strict;
use warnings;
use MIME::Parser;
use MIME::Entity;
use MIME::Body;
use MIME::WordDecoder;
use Cwd;
use File::Path;

my (@body, $i, $subentity);
my $parser = new MIME::Parser;

#new attachment code start
#these are the types of attachments allowed
my @attypes= qw(application/msword
                application/pdf
                application/gzip
                application/tar
                application/tgz
                application/zip
                audio/alaw-basic
                audio/vox
                audio/wav
                image/bmp
                image/gif
                image/jpeg
                text/html
                text/plain
                text/vxml
);
my ($x, $newx, @attachment, $attachment, @attname, $bh, $nooatt);

# alustetaan liitelukum. aluksi nollaksi
$nooatt = 0;

#new attachement code end
my $to;      #contains the message to header
my $from;    #contains the message from header
my $subject; #contains the message subject heaer
my $body;    #contains the message body


$parser->ignore_errors(1);
$parser->output_to_core(1);

my $entity = $parser->parse(\*STDIN);
my $error = ($@ || $parser->last_error);

#get email headers
my $header = $entity->head;
$subject = $header->get('Subject');
$to = $header->get('To');
$from = $header->get('From');

chomp($subject);
chomp($to);
chomp($from);

#get email body
if ($entity->parts > 0){
    for ($i=0; $i<$entity->parts; $i++){
        
        $subentity = $entity->parts($i);
        
        if (($subentity->mime_type =~ m/text\/html/i) || ($subentity->mime_type =~ m/text\/plain/i)){
            $body = join "",  @{$subentity->body};
            #new attachment code start
            next;
            #new attachment code end
        }
        
        #this elsif is needed for Outlook's nasty multipart/alternative messages
        elsif ($subentity->mime_type =~ m/multipart\/alternative/i){

            $body = join "",  @{$subentity->body};
            
            #split html and text parts
            @body = split /------=_NextPart_\S*\n/, $body;
            
            #assign the first part of the message,
            #hopefully the text, part as the body
            $body = $body[1]; 
            
            #remove leading headers from body
            $body =~ s/^Content-Type.*Content-Transfer-Encoding.*?\n+//is;
            #new attachment code start
            next;
            #new attachment code end
        }

        #new attachment code start
        #grab attachment name and contents
        foreach $x (@attypes){
            if ($subentity->mime_type =~ m/$x/i){
                $bh = $subentity->bodyhandle;
                $attachment = $bh->as_string;
                push @attachment, $attachment;
                push @attname, $subentity->head->mime_attr('content-disposition.filename');
            }else{
                #some clients send attachments as application/x-type.
                #checks for that
                $newx = $x;
                $newx =~ s/application\/(.*)/application\/x-$1/i;
                if ($subentity->mime_type =~ m/$newx/i){
                    $bh = $subentity->bodyhandle;
                    $attachment = $bh->as_string;
                    push @attachment, $attachment;
                    push @attname, $subentity->head->mime_attr('content-disposition.filename');
                }
            }
            
        }
        $nooatt = $#attachment + 1;
        #new attachment code end
    }
} else {
   $body = join "",  @{$entity->body};
}



#body may contain html tags. they will be stripped here
#$body =~ s/(<br>)|(<p>)/\n/gi;           #create new lines
#$body =~ s/<.+\n*.*?>//g;                #remove all <> html tages
#$body =~ s/(\n|\r|(\n\r)|(\r\n)){3,}//g; #remove any extra new lines
#$body =~ s/\&nbsp;//g;                   #remove html &nbsp characters

$body =~s/=F6/\&\#246\;/g; #o-kirjain
$body =~s/=E4/\&\#228\;/g; #a-kirjain
$body =~s/=C4/\&\#196\;/g; #A-kirjain
$body =~s/=D6/\&\#214\;/g; #O-kirjain

$body =~s/=C3=A4/\&\#228\;/g; #a-kirjain
$body =~s/=C3=84/\&\#196\;/g; #A-kirjain
$body =~s/=C3=B6/\&\#246\;/g; #o-kirjain
$body =~s/=C3=96/\&\#214\;/g; #O-kirjain

$body =~ s/(\n|\r|(\n\r)|(\r\n)){3,}/<br\>/g;
$body =~s/=//g; # =-merkit pois


#remove trailing whitespace from body
#$body =~ s/\s*\n+$//s;




#new attachment code start

#aikatieto
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$min = sprintf("%02d",$min);
$year = $year + 1900;
$mon = sprintf("%02d", ($mon + 1));

my ($trimmedTime) = sprintf("%02d%02d%02d\_%02d$min", $mday, $mon, $year, $hour);


### Construct a decoder:
my $wd = default MIME::WordDecoder;

if ($header->get('Content-Type') and $header->get('Content-Type') =~ m!charset="([^\"]+)"!)
{
    $wd = supported MIME::WordDecoder uc $1;
}
$wd = supported MIME::WordDecoder "ISO-8859-1" unless $wd;
         
### Convert some MIME text to a pure ASCII string...   
my $decodedSubject = $wd->decode($subject);

#trimmataan otsikosta pois välilyönnit
my ($trimmedSubject) = $decodedSubject;
for ($trimmedSubject) 
{
     s/^\s+//;
     s/\s+$//;
     s/\ /\_/g;
     s/\:/\_/g;
}

#Luodaan hakemistot jos tarpeen
chdir "./public_html/imgBlog/";
my $currWorkDir = Cwd::cwd();
my $newDirText = "$year/$mon/text";
my $newDirImg = "$year/$mon/img";
my $fullPathText = $currWorkDir . '/' . $newDirText;
my $fullPathImg = $currWorkDir . '/' . $newDirImg;

File::Path::mkpath($fullPathText);
File::Path::mkpath($fullPathImg);



#Tallennetaan otsikko, teksti ja tiedot liitteista omaan tekstitiedostoon
open BH, ">./$newDirText/$trimmedTime\_$trimmedSubject.txt" || die "cannot open BH: $!";
print BH "Otsikko: $decodedSubject\n\n";
print BH "Leipateksti:\n$body\n\n";
print BH "Liitteet:\n";
for ($x = 0; $x < $nooatt; $x++)
{
     $attname[$x] = sprintf("$trimmedTime\_$attname[$x]");
     print BH "$attname[$x]\n";
}
close BH;

#tallenneteaan kuvat
for ($x = 0; $x < $nooatt; $x++) 
{
    open FH, ">./$newDirImg/$attname[$x]" || die "cannot open FH: $!";
    print FH "$attachment[$x]";
    close FH;
}




# Kirjoitetaan tavarat html-tiedostoon

#luetaan vanha sisalto
open(FILE, "../imageBlogData.html") or die "Can't open file for reading: $!\n";
my @file = <FILE>;
close(FILE);


#kirjoitetaan uusi sisalto
open(BLOGHTML, ">../imageBlogData.html") or die "Can't open file for writing: $!\n";
print BLOGHTML "<tr>\n";
if($nooatt == 0)
{
    print BLOGHTML "<td colspan=\"2\">\n<b>";
}
else
{
    print BLOGHTML "<td>\n";
}
print BLOGHTML "<p class=\"otsikko\">";
print BLOGHTML "$hour:$min $mday.$mon.$year - $decodedSubject\n";
print BLOGHTML "</p>\n";

print BLOGHTML "<p class=\"leipateksti\">";
print BLOGHTML "$body\n";
print BLOGHTML "</p>";
print BLOGHTML "</td>\n";
for ($x = 0; $x < $nooatt; $x++)
{
    print BLOGHTML "<td>\n";
    print BLOGHTML "<img src=\"imgBlog/$newDirImg/$attname[$x]\" borders=\"0\" width=\"500\">\n";
    print BLOGHTML "</td>\n";
}
print BLOGHTML "</tr>\n";


#tulostetaan vanha sisalto
foreach (@file) 
{
    print BLOGHTML $_;
}


close(BLOGHTML);




