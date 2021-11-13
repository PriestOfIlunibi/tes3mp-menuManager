# menuManager
For 0.7.0alpha
## Features
* Create menus from lua tables, allowing your code to be cleaner and more organized
* Requirement and destination system allows for elegantly expressing complex menu flow
* onGUIAction Handler allows for one unified script to handle GUI checks
### How to Install
1. Place 'menuManager.lua' in 'scripts/custom'.
2. Add menuManager = require("custom.menuManager") in server/scripts/customScripts.lua (copy and paste if need be)
3. (For scripters who wish to test) Add testMenus.lua to scripts/custom, and add require("custom.testMenus") in customScripts.lua
### Creating Menus
* Check menuManager.lua and testMenus.lua for examples/information on how to format your menus. Refer to step 3 of the installation instructions above if you wish to see testMenus.lua in action.
