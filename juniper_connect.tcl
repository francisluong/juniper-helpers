package provide JuniperConnect 1.0
package require Expect  5.45
package require Tcl     8.5

namespace eval ::juniperconnect {
  namespace export connectssh disconnect

  variable session_array
  array unset session_array
  array set session_array {}

  variable basic_rp_prompt_regexp
  set basic_rp_prompt_regexp {[>#%]}

  variable rp_prompt_array
  set rp_prompt_array(Juniper) {([a-z]+@[a-zA-Z0-9\.\-\_]+[>#%])}
}

proc ::juniperconnect::connectssh {address username password} {
  variable session_array 
  variable rp_prompt_array
  set prompt $rp_prompt_array(Juniper)
  set success 0
  set send_slow {1 .1}
  set retries 10
  while {$success==0 && $retries>0} {
    set catch_result [ catch {spawn ssh $username@$address} reason ]
    if {$catch_result>0} {
      return -code error "juniperconnect::connectssh $username@$address: failed to connect: $reason\n"
    }    
    set timeout 120
    send "\n"
    expect {
      -re "(Last login: |$prompt)" {
        set success 1
      }
      "no hostkey alg" {
        return -code error "ERROR: juniperconnect::connectssh: no hostkey alg"
      }
      "Host key verification failed." {
        return -code error "ERROR: FATAL: Mismatched SSH host key for $address"
      }
      "Could not resolve hostname"              {
         puts "juniperconnect::connectssh: $expect_out(0,string)"
         exp_close; exp_wait
         set retries -2
         break
      }
      "Permission denied, please try again" {
         puts "juniperconnect::connectssh: $expect_out(0,string)"
         exp_close; exp_wait
         set retries -1
         break
      }
      "% Bad passwords" { 
         puts "juniperconnect::connectssh: $expect_out(0,string)"
         exp_close; exp_wait
         set retries -1
         break
      }
      "can't be established." {
        expect {(yes/no)?} {
          send "yes\r"
        }
        exp_continue
      }
      -re "Connection (refused|closed)" { 
        puts "juniperconnect::connectssh: $expect_out(0,string)"
        exp_close; exp_wait
        after 2000
      }
      -re "(% Login invalid|Login incorrect|% Authentication failed.|ermission denied|Password Incorrect)" { 
        exp_continue
      }
      -re "( JUNOS )" { 
        exp_continue
      } 
      -re "(Username: |login: )" {
        send -s "$username\r"
        exp_continue
      } 
      -re "($address's password:|Password:|Telnet password:)" { 
        send -s "$password\r"
        exp_continue
      }
      timeout {
        return -code error "juniperconnect::connectssh: TIMEOUT: timed out during login into $address"
      }
    }
    after 1000
    incr retries -1
  }
  if {$retries<1} {
    switch -- $retries {
      "0"       {set err_string "'Connection refused'" }
      "-1"      {set err_string "'Bad passwords'" }
      "-2"      {set err_string "'Bad Hostname'" }
    }
    return -code error "juniperconnect::connectssh: Error count exceeded for error $err_string error"
  }
  set timeout 10
  log_user 1
  puts "\njuniperconnect::connectssh success"
  set session_array($address) $spawn_id
  return $spawn_id
}

proc ::juniperconnect::disconnect {address} {
  variable session_array
  variable rp_prompt_array
  set prompt $rp_prompt_array(Juniper)
  set spawn_id $session_array($address)
  set timeout 1
  send "exit\n"
  expect -re $prompt {}
  puts "\njuniperconnect::disconnect"
  catch {exp_close}
  catch {exp_wait}
}
