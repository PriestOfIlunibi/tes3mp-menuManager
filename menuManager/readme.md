# menuManager
For 0.7.0alpha
## Features
* Loads menus from specified .JSON files, allowing for users to easily create menus.
* Formatting for said JSON menus is very flexible, allowing easy use.
* Function calls within identifying menu data are allowed (including to external scripts), allowing scripters to have dynamically changing menu data.
* onGUIAction Handler allows for one unified script to check idGui data, doing so quickly via constructing function jumps using identifying data.
### How to Install
1. Create a folder called 'menuManager' in server\scripts\custom, and place the base.lua script there.
2. Add menuManager = require("custom.menuManager.base") to the end of server/scripts/customScripts.lua (copy and paste if need be)
3. For any menu that must be added, add the path of the file to be loaded to the 'sources' table, formatted in the same manner as the example.
4. Remember to add accompanying lua scripts for each added menu file, if there are any.
5. (For scripters who wish to test) Add example.lua to server\scripts\custom\menuManager, and require it in customScripts.lua ( "custom.menuManager.example"). Also add exampleManagedMenu.json to data/custom/managedmenus/ (you will probably have to create that last folder)
### Creating & Loading Custom Menus
* Check the exampleManagedMenu.json and its accompanying (commented) .txt file for examples/information on how to format your menus. Refer to step 5 of the installation instructions above if you wish to test this menu file.
### Known issues
* Functions that are defined inside a menu may not work correctly. Workaround: Limit your functions to either be extremely lightweight or to act as a middleman call to your lua script where you can more easily write code without being constricted by .json formatting.
