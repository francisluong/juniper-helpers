package provide JuniperConnect 1.0
package require textproc 1.0
package require Expect  5.45
package require Tcl     8.5

namespace eval ::juniperconnect {
  namespace export connectssh disconnectssh

  variable session_array
  array unset session_array
  array set session_array {}

  variable basic_rp_prompt_regexp
  set basic_rp_prompt_regexp {[>#%]}

  variable rp_prompt_array
  set rp_prompt_array(Juniper) {([a-z]+@[a-zA-Z0-9\.\-\_]+[>#%])}

  variable expect_timeout 10
  variable expect_timeout_restore $expect_timeout
  variable output {}

  proc connectssh {address username password} {
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

  proc disconnectssh {address} {
    variable session_array
    variable rp_prompt_array
    set prompt $rp_prompt_array(Juniper)
    set spawn_id $session_array($address)
    if {$spawn_id ne ""} {
      #send exit
      set timeout 1
      send "exit\n"
      expect -re $prompt {}
      puts "\njuniperconnect::disconnect"
      #close/wait for expect session
      catch {exp_close}
      catch {exp_wait}
      #clear the value stored in the session array
      set session_array($address) ""
    }
  }

  proc set_timeout {timeout_value_sec} {
    #set the expect_timeout value
    variable expect_timeout
    set expect_timeout $timeout_value_sec
  }

  proc restore_timeout {} {
    #revert the expect_timeout value to default
    variable expect_timeout
    variable expect_timeout_default
    set expect_timeout $expect_timeout_restore
  }

  proc timeout {} {
    #get the expect_timeout value
    variable expect_timeout
    return $expect_timeout
  }

  proc send_textblock {address commands_textblock} {
    set textblock [string trim $commands_textblock]
    set commands_list [textproc::nsplit $textblock]
    return [send_commands $address $commands_list]
  }

  proc send_commands {address commands_list} {
    #send a list of commands to the router expecting prompt between each
    variable rp_prompt_array
    set prompt $rp_prompt_array(Juniper)
    set procname "send_commands"
    set tclfilename [namespace current]

    #initialize return output
    variable output
    set output {}

    set timeout [timeout]
    set mode "cli"
    variable session_array
    set spawn_id $session_array($address)

    #send initial carriage-return then expect first prompt
    send "\n"
    expect {
      -re $prompt {append output [string trimleft $expect_out(buffer)]}
      timeout {
        return -code error "ERROR: $procname: TIMEOUT waiting for initial prompt"
      }
    }
    #loop through commands list
    foreach this_command $commands_list {
      #determine if we need to adjust the prompt based on mode switches
      # need a simpler prompt for shell
      switch -- $mode {
        "cli" {
          #if we are in cli mode and we see 'start shell', switch mode/prompt
          switch -- $this_command {
            "start shell" {
              set mode "shell"
              variable basic_rp_prompt_regexp
              #set prompt "%"
              set prompt $basic_rp_prompt_regexp
            }
          }
        }
        "shell" {
          #if we are in shell mode and we see 'exit', switch back to cli
          switch -- $this_command {
            "exit" {
              set mode "cli"
              set prompt $rp_prompt_array(Juniper)
            }
          }
        }
      }
      #send command
      send "$this_command\n"
      #loop and look for for prompt regexp
      expect {
        -re "$prompt" {
          #got prompt - exit condition for expect-loop
          append output $expect_out(buffer)
        }
        -re ".*(\r|\n)" {
          #this resets the timeout timer using newline-continues
          append output $expect_out(buffer)
          exp_continue
        }
        timeout {
          puts "$procname: TIMEOUT waiting for prompt"
          #because of the for-loop this sucker may just keep going, but it's possible the cli has siezed up
        }
      }
    }
    set output [string trimright [textproc::nrange $output 0 end-1]]
    set output [join [split $output "\r"] ""]
    return $output
  }

  proc grep_output {expression textblock} {
    return [textproc::linematch $expression $juniperconnect::output]
  }
}

namespace import juniperconnect::connectssh juniperconnect::disconnectssh

