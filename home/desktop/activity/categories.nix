# What the time goes to: the first category whose app or domain matches wins
# (SQLite GLOB over lowercase app ids and domains). A browser's time takes its
# tab's domain; a browser tab that matches nothing is "Browsing".
{
  browsers = [
    "librewolf"
    "chromium-browser"
    "brave-browser"
    "firefox"
  ];

  rules = [
    {
      name = "Code";
      apps = [
        "emacs"
        "foot"
        "alacritty"
        "kitty"
        "com.mitchellh.ghostty"
        "dev.zed.zed"
        "cursor"
        "code"
        "antigravity*"
      ];
      domains = [
        "github.com"
        "*.github.com"
        "*.github.io"
        "gitlab.com"
        "codeberg.org"
        "*nixos.org"
        "*nixos.wiki"
        "noogle.dev"
        "hexdocs.pm"
        "elixirforum.com"
        "pkg.go.dev"
        "go.dev"
        "crates.io"
        "docs.rs"
        "*.rust-lang.org"
        "developer.mozilla.org"
        "stackoverflow.com"
        "*.stackexchange.com"
        "localhost"
        "127.0.0.1"
        "docs.python.org"
        "*.readthedocs.io"
      ];
    }
    {
      name = "Security";
      apps = [
        "burpsuite"
        "caido"
        "wireshark*"
        "cyberchef"
        "ghidra*"
        "cutter"
      ];
      domains = [
        "*hackthebox.com"
        "tryhackme.com"
        "*.portswigger.net"
        "portswigger.net"
        "book.hacktricks.*"
        "gtfobins.github.io"
      ];
    }
    {
      name = "Research";
      apps = [ ];
      domains = [
        "*.wikipedia.org"
        "arxiv.org"
        "scholar.google.*"
        "grok.com"
        "chatgpt.com"
        "claude.ai"
        "gemini.google.com"
        "perplexity.ai"
        "protesilaos.com"
        "*.medium.com"
        "medium.com"
        "dev.to"
      ];
    }
    {
      name = "Communication";
      apps = [
        "discord"
        "vesktop"
        "*telegram*"
        "signal"
        "thunderbird"
        "slack"
      ];
      domains = [
        "mail.proton.me"
        "mail.google.com"
        "web.whatsapp.com"
        "web.telegram.org"
        "discord.com"
        "*.slack.com"
        "teams.microsoft.com"
        "meet.google.com"
        "calendar.google.com"
        "calendar.proton.me"
      ];
    }
    {
      name = "Games";
      apps = [
        "steam_app_*"
        "steam"
        "gamescope"
        "heroic"
        "lutris"
        "*albion*"
        "minecraft*"
        "retroarch"
      ];
      domains = [ ];
    }
    {
      name = "Media";
      apps = [
        "mpv"
        "vlc"
        "spotify"
        "com.github.unrud.videodownloader"
      ];
      domains = [
        "youtube.com"
        "www.youtube.com"
        "music.youtube.com"
        "twitch.tv"
        "www.twitch.tv"
        "netflix.com"
        "www.netflix.com"
        "*primevideo.com"
        "open.spotify.com"
      ];
    }
    {
      name = "Social";
      apps = [ ];
      domains = [
        "reddit.com"
        "*.reddit.com"
        "x.com"
        "twitter.com"
        "instagram.com"
        "www.instagram.com"
        "*.facebook.com"
        "news.ycombinator.com"
        "lobste.rs"
        "*.linkedin.com"
      ];
    }
    {
      name = "Creative";
      apps = [
        "gimp*"
        "org.inkscape.inkscape"
        "krita"
        "blender"
        "darktable"
        "ardour*"
        "audacity"
        "cockos-reaper"
        "resolve"
        "com.obsproject.studio"
      ];
      domains = [
        "figma.com"
        "www.figma.com"
      ];
    }
    {
      name = "Documents";
      apps = [
        "libreoffice*"
        "soffice"
        "org.pwmt.zathura"
        "org.gnome.evince"
        "okular"
        "xournalpp"
      ];
      domains = [
        "docs.google.com"
        "drive.proton.me"
        "drive.google.com"
        "notion.so"
        "www.notion.so"
      ];
    }
    {
      name = "System";
      apps = [
        "org.gnome.nautilus"
        "org.pulseaudio.pavucontrol"
        ".blueman-manager-wrapped"
        "nm-connection-editor"
        "dotnix-rebuild"
        "*zenity"
        "com.cloudflare.*"
        "proton*"
      ];
      domains = [ ];
    }
  ];
}
