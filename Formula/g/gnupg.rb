class Gnupg < Formula
  desc "GNU Pretty Good Privacy (PGP) package"
  homepage "https://gnupg.org/"
  url "https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.5.0.tar.bz2"
  sha256 "2222c827d4e7087f15e7f72739d004abc1d05c6c5f0a5a12b24c6a6cc5d173fb"
  license "GPL-3.0-or-later"

  livecheck do
    url "https://gnupg.org/ftp/gcrypt/gnupg/"
    regex(/href=.*?gnupg[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    sha256 arm64_sonoma:   "bcb60ed535c0e2e5ac97bc49977246d94455d5b6a74ed9366377249f78e782fb"
    sha256 arm64_ventura:  "fc5d5508f278f822b57e1e05fc4a1cee1116fb3f6521fbc523669e6862d104fe"
    sha256 arm64_monterey: "ada53b5a636355f354ff11584e2f488bf167ef7ba1d3e20ce742ee286b47cc6c"
    sha256 sonoma:         "45ad3a0750e638402ecd6135219ba4592b847d2c5e5a27c3e05657d3433bf5ec"
    sha256 ventura:        "acb0a737a9f5c10a50348b3aaa0f247ea578c7b84d86ccdaafb22c818d7b7426"
    sha256 monterey:       "23a18b638018bb3ee5339dbb00d16b4ef58047a351903ebeef72335e9565e4b8"
    sha256 x86_64_linux:   "9a7d57f7e335fd7b506848fa15ee1be52d8940b8c5dfc0c6a3c8d9f406fbeb93"
  end

  depends_on "pkg-config" => :build
  depends_on "gnutls"
  depends_on "libassuan"
  depends_on "libgcrypt"
  depends_on "libgpg-error"
  depends_on "libksba"
  depends_on "libusb"
  depends_on "npth"
  depends_on "pinentry"
  depends_on "readline"

  uses_from_macos "bzip2"
  uses_from_macos "openldap"
  uses_from_macos "sqlite", since: :catalina
  uses_from_macos "zlib"

  on_macos do
    depends_on "gettext"
  end

  # Declare environ
  patch :DATA

  # Upstream fix, remove in next version
  # https://git.gnupg.org/cgi-bin/gitweb.cgi?p=gnupg.git;a=commit;h=1d5cfa9b7fd22e1c46eeed5fa9fed2af6f81d34f
  patch do
    url "https://git.gnupg.org/cgi-bin/gitweb.cgi?p=gnupg.git;a=patch;h=1d5cfa9b7fd22e1c46eeed5fa9fed2af6f81d34f"
    sha256 "610d0c50004e900f1310f58255fbf559db641edf22abb86a6f0eb6c270959a5d"
  end

  def install
    libusb = Formula["libusb"]
    ENV.append "CPPFLAGS", "-I#{libusb.opt_include}/libusb-#{libusb.version.major_minor}"

    mkdir "build" do
      system "../configure", *std_configure_args,
                             "--disable-silent-rules",
                             "--sysconfdir=#{etc}",
                             "--enable-all-tests",
                             "--with-pinentry-pgm=#{Formula["pinentry"].opt_bin}/pinentry"
      system "make"
      system "make", "check"
      system "make", "install"
    end

    # Configure scdaemon as recommended by upstream developers
    # https://dev.gnupg.org/T5415#145864
    if OS.mac?
      # write to buildpath then install to ensure existing files are not clobbered
      (buildpath/"scdaemon.conf").write <<~EOS
        disable-ccid
      EOS
      pkgetc.install "scdaemon.conf"
    end
  end

  def post_install
    (var/"run").mkpath
    quiet_system "killall", "gpg-agent"
  end

  test do
    (testpath/"batch.gpg").write <<~EOS
      Key-Type: RSA
      Key-Length: 2048
      Subkey-Type: RSA
      Subkey-Length: 2048
      Name-Real: Testing
      Name-Email: testing@foo.bar
      Expire-Date: 1d
      %no-protection
      %commit
    EOS
    begin
      system bin/"gpg", "--batch", "--gen-key", "batch.gpg"
      (testpath/"test.txt").write "Hello World!"
      system bin/"gpg", "--detach-sign", "test.txt"
      system bin/"gpg", "--verify", "test.txt.sig"
    ensure
      system bin/"gpgconf", "--kill", "gpg-agent"
    end
  end
end

__END__
--- a/common/exechelp-posix.c
+++ b/common/exechelp-posix.c
@@ -76,6 +76,8 @@
 #include "sysutils.h"
 #include "exechelp.h"
 
+extern char **environ; 
+
 
 /* Helper */
 static inline gpg_error_t
