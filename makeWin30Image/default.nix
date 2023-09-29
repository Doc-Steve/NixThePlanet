{ fetchFromBittorrent
, runCommand
, unzip
, dosbox-x
, xvfb-run
, x11vnc
, tesseract
, expect
, vncdo
, writeScript
, writeShellScript
, writeText
, makeMsDos622Image
, fetchFromGitHub
}:
{ ... }:
let
  dosbox-x-fix = dosbox-x.overrideAttrs {
    src = fetchFromGitHub {
      owner = "joncampbell123";
      repo = "dosbox-x";
      rev = "d2febc9ad28c7e3a4e4c3f52c8159d693078679b";
      hash = "sha256-O+qpdkHOHSYG2BSlNxeTW+tMRUxrnQW/iEFx6DIGOik=";
    };
  };
  msDos622 = makeMsDos622Image {};

  win30 = fetchFromBittorrent {
    url = "https://archive.org/download/windows-3.0-720-kb-disks/windows-3.0-720-kb-disks_archive.torrent";
    hash = "sha256-PJ+qM0lFSYy+DC08myJGrtDQGZOQHltc0JRjV+niNXA=";
  };

  dosboxConf = writeText "dosbox.conf" ''
    [cpu]
    turbo=on
    stop turbo on key = false

    [autoexec]
    imgmount C msdos622.img -size 512,63,16,507 -t hdd -fs fat
    imgmount A win30/DISK01.IMG win30/DISK02.IMG win30/DISK03.IMG win30/DISK04.IMG win30/DISK05.IMG win30/DISK06.IMG win30/DISK07.IMG -t floppy -fs fat
    boot -l C
  '';

  tesseractScript = writeShellScript "tesseractScript" ''
    export OMP_THREAD_LIMIT=1
    cd $(mktemp -d)
    TEXT=""
    while true
    do
      sleep 3
      ${vncdo}/bin/vncdo -s 127.0.0.1::5900 capture cap.png
      NEW_TEXT="$(${tesseract}/bin/tesseract cap.png stdout 2>/dev/null)"
      if [ "$TEXT" != "$NEW_TEXT" ]; then
        echo "$NEW_TEXT"
        TEXT="$NEW_TEXT"
      fi
    done
  '';

  expectScript = let
    vncdoWrapper = writeScript "vncdoWrapper" ''
      ${vncdo}/bin/vncdo --force-caps -s 127.0.0.1::5900 "$@"
    '';
  in writeScript "expect.sh"
  ''
    #!${expect}/bin/expect -f
    set debug 5
    set timeout -1
    spawn ${tesseractScript}
    expect "CiN"
    exec ${vncdoWrapper} type "A:" key enter pause 1 type "SETUP.EXE" pause 1 key enter
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    expect "To exit Setup"
    exec ${vncdoWrapper} key enter
    expect "Setup is ready to install Windows"
    exec ${vncdoWrapper} key enter
    expect "No Changes"
    exec ${vncdoWrapper} key enter
    expect "Disk #2"
    exec ${vncdoWrapper} key f12-o pause 1 key enter
    expect "Windows Setup"
    exec ${vncdoWrapper} key tab key tab key tab key enter
    expect "Disk #3"
    exec ${vncdoWrapper} key f12-o pause 1 key enter
    expect "Disk #4"
    exec ${vncdoWrapper} key f12-o pause 1 key enter
    expect "Disk #5"
    exec ${vncdoWrapper} key f12-o pause 1 key enter
    expect "Disk #6"
    exec ${vncdoWrapper} key f12-o pause 1 key enter
    expect "select the option you"
    exec ${vncdoWrapper} key enter
    expect "The new versions"
    exec ${vncdoWrapper} key enter
    expect "List of Printers"
    exec ${vncdoWrapper} key esc
    expect "Set Up Applications"
    exec ${vncdoWrapper} key enter
    expect "applications for Windows 3.0"
    exec ${vncdoWrapper} key enter pause 1 key tab pause 1 key tab pause 1 key tab pause 1 key tab pause 1 key tab pause 1 key enter
    expect "For Help using Notepad"
    exec ${vncdoWrapper} key alt-f4
    expect "remove the floppy disk and choose Reboot"
    exec ${vncdoWrapper} key enter
    expect "CiN"
    send_user "\n### OMG DID IT WORK???!!!! ###\n"
    exit 0
  '';

in
runCommand "win30.img" { buildInputs = [ unzip dosbox-x-fix xvfb-run x11vnc ];
  # set __impure = true; for debugging
  # __impure = true;
    } ''
  echo ${win30}
  mkdir win30
  unzip '${win30}/Microsoft Windows 3.0 (3.5-720K).zip' -d win30
  dd if=/dev/zero of=disk.img count=8192 bs=31941
  cp --no-preserve=mode ${msDos622} ./msdos622.img

  xvfb-run -l -s ":99 -auth /tmp/xvfb.auth -ac -screen 0 800x600x24" dosbox-x -conf ${dosboxConf} || true &
  dosboxPID=$!
  DISPLAY=:99 XAUTHORITY=/tmp/xvfb.auth x11vnc -many -shared -display :99 >/dev/null 2>&1 &
  ${expectScript} &
  wait $!
  kill $dosboxPID
  mv disk.img $out
''
