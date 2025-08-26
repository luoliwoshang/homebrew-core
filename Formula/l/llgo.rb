class Llgo < Formula
  desc "Go compiler based on LLVM integrate with the C ecosystem and Python"
  homepage "https://github.com/luoliwoshang/llgo"
  url "https://github.com/luoliwoshang/llgo/archive/refs/tags/v0.12.12.tar.gz"
  sha256 "20c1c968c955dcc3157445c788804ecbd85dbcac248c99c8dfd27bcc3b09e61d"
  license "Apache-2.0"
  head "https://github.com/luoliwoshang/llgo.git", branch: "main"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    rebuild 1
    sha256 cellar: :any, arm64_sequoia: "0947ad7513fea18ae89e066e0bbb4ed3c6dc0299ead7d69a4cb57b6f3941d36f"
    sha256 cellar: :any, arm64_sonoma:  "7de761a6c845ba0a46d27164595fdf5c779cab4fea67cdcc927b696eab7b97d9"
    sha256 cellar: :any, arm64_ventura: "cacaa00dc85e867d7c346af23319ecc37dd1518acadacb1329072f2764beb52a"
    sha256 cellar: :any, sonoma:        "c1d46f74280d51ae465daa27d47c9e06e4da328d52f74a4b871551d4ccfffab5"
    sha256 cellar: :any, ventura:       "a6022098d5a0ef86f343ce6aca0c983caa53b8c836ab620212da8b459359631b"
    sha256               x86_64_linux:  "2486bc3ddd7c27fe03c9ae10df73553c09b9f21b3d4dc94b55f99da632dbbf5f"
  end

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "python@3.13" => :build
  depends_on "bdw-gc"
  depends_on "go@1.24"
  depends_on "libffi"
  depends_on "libuv"
  depends_on "openssl@3"
  depends_on "pkgconf"
  uses_from_macos "zlib"

  resource "espressif-llvm" do
    url "https://github.com/espressif/llvm-project.git",
        revision: "xtensa_release_19.1.2",
        shallow:  true
  end

  def find_dep(name)
    deps.find { |f| f.name.match?(/^#{name}(@\d+(\.\d+)*)?$/) }
        .to_formula
  end

  def install
    ohai "Platform: #{OS.mac? ? "macOS" : "Linux"} #{Hardware::CPU.arch}"
    ohai "Building ESP32-optimized LLVM toolchain from source..."

    # Build LLVM toolchain from source (replicated from espressif-llvm-project-prebuilt/release.sh)
    resource("espressif-llvm").stage do
      mkdir "build" do
        # Base CMake arguments (from release.sh:67-121)
        base_args = %w[
          -G Ninja
          -DCMAKE_BUILD_TYPE=Release
          -DLLVM_TARGETS_TO_BUILD=X86;ARM;AArch64;AVR;Mips;RISCV;WebAssembly
          -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=Xtensa
          -DLLVM_ENABLE_PROJECTS=clang;lld
          -DLLVM_ENABLE_RUNTIMES=compiler-rt;libcxx;libcxxabi;libunwind
          -DLLVM_POLLY_LINK_INTO_TOOLS=ON
          -DLLVM_BUILD_EXTERNAL_COMPILER_RT=ON
          -DLLVM_ENABLE_EH=ON
          -DLLVM_ENABLE_RTTI=ON
          -DLLVM_INCLUDE_DOCS=OFF
          -DLLVM_INCLUDE_EXAMPLES=OFF
          -DLLVM_INCLUDE_TESTS=OFF
          -DLLVM_INCLUDE_BENCHMARKS=OFF
          -DLLVM_BUILD_DOCS=OFF
          -DLLVM_ENABLE_DOXYGEN=OFF
          -DLLVM_INSTALL_UTILS=ON
          -DLLVM_ENABLE_Z3_SOLVER=OFF
          -DLLVM_OPTIMIZED_TABLEGEN=ON
          -DLLVM_USE_RELATIVE_PATHS_IN_FILES=ON
          -DLLVM_SOURCE_PREFIX=.
          -DLIBCXX_INSTALL_MODULES=ON
          -DCLANG_FORCE_MATCHING_LIBCLANG_SOVERSION=OFF
          -DCOMPILER_RT_BUILD_SANITIZERS=OFF
          -DCOMPILER_RT_BUILD_XRAY=OFF
          -DCOMPILER_RT_BUILD_LIBFUZZER=OFF
          -DCOMPILER_RT_BUILD_PROFILE=OFF
          -DCOMPILER_RT_BUILD_MEMPROF=OFF
          -DCOMPILER_RT_BUILD_ORC=OFF
          -DCOMPILER_RT_BUILD_GWP_ASAN=OFF
          -DCOMPILER_RT_BUILD_CTX_PROFILE=OFF
          -DCMAKE_POSITION_INDEPENDENT_CODE=ON
          -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF
          -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON
          -DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON
          -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON
          -DLIBCXX_STATICALLY_LINK_ABI_IN_SHARED_LIBRARY=OFF
          -DLIBCXX_STATICALLY_LINK_ABI_IN_STATIC_LIBRARY=ON
          -DLIBCXX_USE_COMPILER_RT=ON
          -DLIBCXX_HAS_ATOMIC_LIB=OFF
          -DLIBCXXABI_ENABLE_STATIC_UNWINDER=ON
          -DLIBCXXABI_STATICALLY_LINK_UNWINDER_IN_SHARED_LIBRARY=OFF
          -DLIBCXXABI_STATICALLY_LINK_UNWINDER_IN_STATIC_LIBRARY=ON
          -DLIBCXXABI_USE_COMPILER_RT=ON
          -DLIBCXXABI_USE_LLVM_UNWINDER=ON
          -DLIBUNWIND_USE_COMPILER_RT=ON
          -DSANITIZER_CXX_ABI=libc++
          -DSANITIZER_TEST_CXX=libc++
          -DLLVM_LINK_LLVM_DYLIB=ON
          -DCLANG_LINK_CLANG_DYLIB=ON
        ]

        # Platform-specific arguments (from release.sh:124-142 and 145-152)
        platform_args = []
        if OS.mac?
          arch = Hardware::CPU.arm? ? "arm64" : "x86_64"
          platform_args += %W[
            -DLLVM_BUILD_LLVM_C_DYLIB=ON
            -DLLVM_ENABLE_LIBCXX=ON
            -DLIBCXX_PSTL_BACKEND=libdispatch
            -DCMAKE_OSX_SYSROOT=#{MacOS.sdk_path}
            -DCMAKE_OSX_ARCHITECTURES=#{arch}
            -DLIBCXXABI_USE_SYSTEM_LIBS=ON
          ]
        else
          platform_args += %w[
            -DLLVM_ENABLE_LIBXML2=OFF
            -DLLVM_ENABLE_LIBCXX=OFF
            -DCLANG_DEFAULT_CXX_STDLIB=libstdc++
            -DLLVM_BUILD_LLVM_DYLIB=ON
            -DCOMPILER_RT_USE_LLVM_UNWINDER=ON
          ]
        end

        # Install LLVM to crosscompile/clang directory
        clang_install_prefix = libexec/"crosscompile/clang"
        cmake_args = base_args + platform_args + ["-DCMAKE_INSTALL_PREFIX=#{clang_install_prefix}"]

        ohai "Configuring LLVM build..."
        system "cmake", "../llvm", *cmake_args

        ohai "Building LLVM (this may take 30-60 minutes)..."
        ENV["NINJA_STATUS"] = "[%f/%t] "
        system "ninja", "-j#{ENV.make_jobs}"

        ohai "Installing LLVM toolchain..."
        system "ninja", "install"

        ohai "LLVM toolchain installed to: #{clang_install_prefix}"
      end
    end

    local_llvm_config = libexec/"crosscompile/clang/bin/llvm-config"

    ldflags = %W[
      -s -w
      -X github.com/goplus/llgo/internal/env.buildVersion=v#{version}
      -X github.com/goplus/llgo/internal/env.buildTime=#{time.iso8601}
      -X github.com/goplus/llgo/xtool/env/llvm.ldLLVMConfigBin=#{local_llvm_config}
    ]

    # Set CGO environment for both macOS and Linux to use our built LLVM
    local_llvm_include = libexec/"crosscompile/clang/include"
    local_llvm_lib = libexec/"crosscompile/clang/lib"

    # Set all required macros and C++ standard before any includes
    ENV["CGO_CPPFLAGS"] = "-D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS -D_GNU_SOURCE -I#{local_llvm_include} #{ENV["CGO_CPPFLAGS"]}"
    ENV["CGO_CXXFLAGS"] = "-std=c++17 -D__STDC_CONSTANT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_LIMIT_MACROS #{ENV["CGO_CXXFLAGS"]}"

    # Force use of our built LLVM, not system LLVM
    ENV["CGO_LDFLAGS"] = "-L#{local_llvm_lib} -lLLVM #{ENV["CGO_LDFLAGS"]}"
    # Also set library path for macOS dyld
    ENV["DYLD_LIBRARY_PATH"] = "#{local_llvm_lib}:#{ENV["DYLD_LIBRARY_PATH"]}"
    tags = "byollvm"

    ohai "CGO setup - Include: #{local_llvm_include}, Lib: #{local_llvm_lib}"

    ohai "Building LLGO..."
    system "go", "build", *std_go_args(ldflags:, tags:), "-o", libexec/"bin/", "./cmd/llgo"

    libexec.install "LICENSE", "README.md", "go.mod", "go.sum", "runtime"

    path_deps = %w[go pkgconf].map { |name| find_dep(name).opt_bin }
    path_deps << (libexec/"crosscompile/clang/bin")
    script_env = { PATH: "#{path_deps.join(":")}:$PATH" }

    if OS.linux?
      script_env[:CFLAGS] = "-I#{local_llvm_include} $CFLAGS"
      script_env[:LDFLAGS] = "-L#{local_llvm_lib} -rpath #{local_llvm_lib} $LDFLAGS"
    end

    # Create wrapper script only for llgo in bin/
    (libexec/"bin").children.each do |f|
      next if f.directory?

      cmd = File.basename(f)
      (bin/cmd).write_env_script libexec/"bin"/cmd, script_env
    end
  end

  test do
    go = find_dep("go")
    goos = shell_output("#{go.opt_bin}/go env GOOS").chomp
    goarch = shell_output("#{go.opt_bin}/go env GOARCH").chomp
    assert_equal "llgo v#{version} #{goos}/#{goarch}", shell_output("#{bin}/llgo version").chomp

    # Add bdw-gc library path to LD_LIBRARY_PATH, this is a workaround for the libgc.so not found issue
    # Will be fixed in the next release
    bdwgc = find_dep("bdw-gc")
    ENV.prepend_path "LD_LIBRARY_PATH", bdwgc.opt_lib

    (testpath/"hello.go").write <<~GO
      package main

      import (
          "fmt"

          "github.com/goplus/lib/c"
          "github.com/goplus/lib/cpp/std"
      )

      func Foo() string {
        return "Hello LLGo by Foo"
      }

      func main() {
        fmt.Println("Hello LLGo by fmt.Println")
        c.Printf(c.Str("Hello LLGo by c.Printf\\n"))
        c.Printf(std.Str("Hello LLGo by cpp/std.Str\\n").CStr())
      }
    GO
    (testpath/"hello_test.go").write <<~GO
      package main

      import "testing"

      func Test_Foo(t *testing.T) {
        got := Foo()
        want := "Hello LLGo by Foo"
        if got != want {
          t.Errorf("foo() = %q, want %q", got, want)
        }
      }
    GO
    (testpath/"go.mod").write <<~GOMOD
      module hello
    GOMOD
    system go.opt_bin/"go", "get", "github.com/goplus/lib"
    # Test llgo run
    assert_equal "Hello LLGo by fmt.Println\n" \
                 "Hello LLGo by c.Printf\n" \
                 "Hello LLGo by cpp/std.Str\n",
                 shell_output("#{bin}/llgo run .")
    # Test llgo build
    system bin/"llgo", "build", "-o", "hello", "."
    assert_equal "Hello LLGo by fmt.Println\n" \
                 "Hello LLGo by c.Printf\n" \
                 "Hello LLGo by cpp/std.Str\n",
                 shell_output("./hello")
    # Test llgo test
    assert_match "PASS", shell_output("#{bin}/llgo test .")
  end
end
