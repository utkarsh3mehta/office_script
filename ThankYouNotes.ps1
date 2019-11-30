## Send special thank you mails to special people in your organization
##


$thankyoucsv = Import-Csv "C:\Users\User\Desktop\Thank YouTest.csv"


# Connect to outlook
$outlook = New-Object -ComObject Outlook.Application

$nocontent = $thankyoucsv | Where-Object {$_.content -eq '' -or $_.content -eq $null}
$nocontactMails = $nocontent.EmailId -split '; ' -split ', ' -join ';'

$body = "<body>
<p>
    Hi All,
</p>
<p>
    It has been a great journey of 2 years in LTI. I've learnt alot here, the good and the necessary. I'm more confident now and I've tried making myself useful.
    I've always tried to be honest and hard-working. I love to help people and I'm greatful of people who recognized this zeel in me and promoted me to the automation team.
    Special thanks to my few close friends and bhais (basically elder friends). I'm so happy to have met you guys. You have definitely made my life easier.
</p>
<p>
    I don't have much stories to share here, but I can leave you with a question to think on.<br/><br/>
    <strong>If life has been about hearing what you cannot do, or what you shouldn't do. Then are we even trying to know the limits of what we can and what we should?</strong><br/><br/>
    Hope to see you soon, in the fields someday.
</p>
<i>
    My contact info:
    <ul>
        <li>Business Email: umtebiz@gmail.com</li>
    </ul>
</i>
<span style=`"color: darkblue; font-weight: 600;`">Warm Regards,</span><br/>
    <span>Utkarsh Mehta</span>
<br/>
<strong>P.S.: Dedicating the subject line to this moment</strong>
</body>"

$mail = $outlook.CreateItem(0)
$mail.Bcc = $nocontactMails
$mail.HTMLBody = $body
$mail.Subject = "https://open.spotify.com/playlist/7njXuEavJNJL9i32guRgsp?si=-gkd0o1oSkSbQZ-V9lrkxg"
$mail.Send()

$yescontent = $thankyoucsv | Where-Object {$_.content -ne '' -and $_.content -ne $null}

foreach($person in $yescontent) {
    $name = $person.Name -split ', '
    $to = $person.EmailId -split '; '
    $content = $person.Content
    $sharableContact = $person.ShareableContact -split ', '

    $rishikable = $person.Rishikable

    for ($i = 0; $i -lt $name.length; $i++) {
        $n = $name[$i]
        $t = $to[$i] -split ', '

        $body = "<body>
        <p>
            Hi $n,
        </p>
        <p>
            It has been a great journey of 2 years in LTI. I've learnt alot here, the good and the necessary. I'm more confident now and I've tried making myself useful.
            I've always tried to be honest and hard-working. I love to help people and I'm greatful of people who recognized this zeel in me and promoted me to the automation team.
            Special thanks to my few close friends and bhais (basically elder friends). I'm so happy to have met you guys. You have definitely made my life easier.
        </p>
        <p>
            I don't have much stories to share here, but I can leave you with a question to think on.<br/><br/>
            <strong>If life has been about hearing what you cannot do, or what you shouldn't do. Then are we even trying to know the limits of what we can and what we should?</strong><br/><br/>
            Hope to see you soon, in the fields someday.
        </p>"

        if ($content -ne $null -and $content -ne '') {
            $body += "<p>
            <strong>
                A special note to you:
            </strong>
            <br/>
            <strong style=`"background-color: yellow;`" >
                $content
            </strong>
        </p>"
        }

        if($rishikable -eq $true) {
            $body += "<p>Btw, now that I'm gone, an ex-close friend of mine is going to be more lonelier than he will accept! He doesn't know of this but can you please do me a favour and just treat him more human than others.<br/><b>P.S.:</b> Don't tell him I asked for this. <br/><b>'He' is the guy who jumps while walking.</b></p>"
        }

        $body += "<i>
        My contact info:
        <ul>"

        if ($sharableContact -ne $null) {
            foreach($contactType in $sharableContact) {
                $contact = $null
                switch($contactType) {
                    'Development' {$contact = "umteappdev@gmail.com"; break}
                    'Call' {$contact = "+91-9819642511/+91-8169501771"; break}
                    'Github' {$contact = "https://github.com/utkarsh3mehta"; break}
                    'Instagram' {$contact = "gharelu_cameraman"; break}
                    'LinkedIn' {$contact = "https://www.linkedin.com/in/utkarsh-mehta-691744138"; break}
                    'Medium' {$contact = "@utkarshmehta143"; break}
                    'Personal' {$contact = "utkarshmehta143@gmail.com"; break}
                    'Twitter' {$contact = "@UtkarshM13"; break}
                    'Whatsapp' {$contact = "9819642511"; break}
                }

                $body += "<li>"+$contactType+": "+$contact+"</li>"
            }
        }
        $body += "<li>Business Email: umtebiz@gmail.com</li>
            </ul>
        </i>"

        $body += "<span style=`"color: darkblue; font-weight: 600;`">Warm Regards,</span><br/>
            <span>Utkarsh Mehta</span>
        <br/>
        <strong>P.S.: Dedicating the subject line to this moment</strong>
        </body>"

        $mail = $outlook.CreateItem(0)
        $mail.Bcc = $t -join ';'
        $mail.HTMLBody = $body
        $mail.Subject = "https://open.spotify.com/playlist/7njXuEavJNJL9i32guRgsp?si=-gkd0o1oSkSbQZ-V9lrkxg"
        $mail.Send()
    }
}

# End outlook connect
$outlook.Quit()