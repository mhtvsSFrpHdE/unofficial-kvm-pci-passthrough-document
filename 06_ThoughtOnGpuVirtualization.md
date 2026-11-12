# Thought on GPU virtualization
In a long time, there is middle layer in GPU virtualization  
that translate API calls like DirectX 8, 9, OpenGL  
some solution provide newer DirectX 11  
and in Microsoft Hyper-V GPU partition,  
share GPU with multiple virtual machine and  
use even more APIs at the same time are possible  
DirectX 12, Vulkan, CUDA, NVENC, read gpu thermal, and clock speed  
basically whatever you can tell, and performance is good  
In WSL2 or later WSL3, you can even have a future that  
install Windows on hardware, then have  
Linux virtual machine with full functional GPU

Why solution like PCI passthough in KVM that  
let one virtual machine one entire GPU still valuable?

Is the GPU driver issue.  
According to this research  
[Cthulhu of Computer Graphics](https://zhuanlan.zhihu.com/p/2082785955996496419)  
It's impossible for a translate layer developer team to  
reporoduce every GPU driver behavior  
Read the original post content to understand more

## Cthulhu of Computer Graphics
What happens if you correctly execute every instruction in 3D program?

...perhaps you'll ends up with a game that low performance, low framerate, can't fully utilize hardware and full of RAM or video memory leaks.

I recently doing research of graphics card virtualization technology like "Microsoft GPU Partition", "KVM PCI Passthrough". Graphics card virtualization sometimes appears in news posted by tech media like "2 Gaming Rigs, 1 Tower". But something doesn't show in short term test but become a problem in daily use. The performance issue, and various type of resource leak bug. Before I have research about gaming issue: [Why run Genshin Impact may fix other games](https://zhuanlan.zhihu.com/p/2008745639794729177)

And now I observed there is performance issue appears in "Honkai Star Rail", "Wuthering Waves", "Arknights Endfield", but not in every game. The severity varies. I wish to know why, and my research got some progress.

All games have performance issue got same characteristic that is running in Hyper-V GPU Partition virtual machine, and if you use dxvk on top of this situation, performance issue are gone. If these game run inside KVM PCI Passthrough GPU virtualization, game has no performance issue too and got very high performance. For example, "Wuthering Waves" in Hyper-V GPU Partition consumes over 10,000 MB of RAM, but in KVM PCI Passthrough it consumes only 2400 MB of RAM. I haven't test "Honkai Star Rail" yet, but likely it won't have bug in KVM PCI Passthrough.

The difference is in Hyper-V GPU Partition, graphics driver "don't know" which process is using graphics card, graphical API calls from game program will first reach a virtual graphics card "Microsoft Basic Render Drive", it acts like real GPU. Then, send graphical requests to real graphics card and driver by using Microsoft program. I think the driver can only know is Microsoft program like "vmmem" are using graphics, but don't know the real program to use graphics is "Wuthering Waves.exe"

And in KVM PCI passthrough, a virtual machine owns entire graphics card as PCI device, interactive device with graphics card driver installs and run inside virtual machine, with no middle layer, graphics driver can know which program is using graphics.

dxvk is kind of middle layer, convert d3d11 API calls to Vulkan then send to graphics card. It also knows which program is using graphics, and because of d3d11 and Vulkan not exactly same thing, lots of feature need to decide by dxvk itself, so dxvk exist similar to graphics driver. You can also see lots of improvements specially to certain games in its open source repository. We also hear some news about dxvk boost Intel graphics card performance, though there is no evidence. Vulkan is a "low level programming API", compare to d3d11, graphics driver "less to know" how graphical programs run. So when "Microsoft Basic Render Driver" are bad to run graphical program, let dxvk handle, know characteristic of graphical program, and interactive with graphics card use low level programming API, so performance is boosted and bug gets fixed.

So far key of everything is all about "graphics driver or things exist similar to graphics driver, know or not know what program is using graphics". If know, issue solved, if not, issue happen.

Side evidence is dxvk issue 5898, "dxvk.conf", "d3d11.cachedDynamicResource" config. When dxvk meet "ffxiv_dx11.exe", it knows this is "FINAL FANTASY XIV", and actively set config to "vi". For "Wuthering Waves", because of dxvk not yet recognize this program, no config is enabled, cause frame rate is only 29 FPS. If manually set "a" in "dxvk.conf", then game restored to 60 FPS and run smooth. We know dxvk exist like graphics driver, then assume the real graphics driver also contains lots of similar patch.

When an error exists in graphical program, not fix by game developer, but fix by patch from graphics card manufactures that integrated into GPU driver, and game developers keep their error out there, it's really weird. You don't imagine an application popular worldwide has sort type of error and cause CPU manufactures push driver patch to fix it, we just let application developer to solve problem on their own. Imagine CPU manufactures release driver fixed log4j security vulnerability! Now everybody goes home, instead of people update their code and publish new version.

No longer be able to tell "Chicken or the egg", that is assume graphical program is always bad, in case of hardware specs can't improve fast, which graphics card brand can fix bugs, which has more FPS, or assume drivers from graphics card brand is mystery, covered errors in graphical program cause graphical program developers can't notice issue and fix them, when people awakes is 2026, an ecological environment that difficult to resolve problems. When new graphics card manufactures come to d3d11 world, the problem is NVIDIA won't share all the patches to exist 3D graphical program for years, this creates an industry barrier. Even if you can build the hardware, software can get in the way.

And the resistance come from game manufactures and graphics card drivers, or d3d11 standard itself has so much "driver to decide" part, I have no idea.

How this research affects people's lives is as higher your graphics driver version, it can "know" more games. But also may have varies new bugs.

Other potential assume is, when graphics card driver know Genshin Impact is running, is there any weird config are turned on, but the config is apply to whole graphics card instead of by process, so it also apply to some other graphical program? These config are close source, we know nothing.

When we are talking a "bad driver" may be because graphical program is bad, and driver not contains patch, a "good driver" that says there is many patches in driver.
