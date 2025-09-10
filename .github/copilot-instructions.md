# Copilot Instructions for sm-plugin-CIDR-Discord

## Repository Overview

This repository contains a SourceMod plugin that integrates CIDR block notifications with Discord webhooks. The plugin extends the CIDR plugin functionality by sending Discord notifications when CIDR-related actions are performed on Source engine game servers.

**Primary Purpose**: Send Discord webhook notifications when CIDR block actions occur
**Target Environment**: Source engine game servers running SourceMod
**Main Plugin File**: `addons/sourcemod/scripting/CIDR_Discord.sp`

## Technical Environment & Dependencies

### Core Dependencies
- **SourceMod**: 1.11.0-git6934+ (target 1.12+ for new features)
- **Build System**: SourceKnight (not direct spcomp compilation)
- **Required Plugins**:
  - CIDR plugin (main dependency - provides `CIDR_OnActionPerformed` forward)
  - MultiColors (for colored text support)
  - DiscordWebhookAPI (for Discord integration)
- **Optional Plugins**:
  - Extended-Discord (for enhanced Discord logging)

### Build Process
- Uses SourceKnight build system configured in `sourceknight.yaml`
- Build command: Use GitHub Actions or SourceKnight CLI with `cmd: build`
- Dependencies are automatically downloaded and configured
- Output: Compiled `.smx` files in `/addons/sourcemod/plugins`

## Code Patterns & Architecture

### Plugin Structure
```sourcepawn
// Standard SourceMod plugin headers with pragmas
#pragma semicolon 1
#pragma newdecls required

// Plugin lifecycle: OnPluginStart() → OnAllPluginsLoaded() → OnConfigsExecuted()
// Main integration point: CIDR_OnActionPerformed() forward
```

### Key Components
1. **Configuration ConVars**: Webhook URL, retry settings, Discord formatting
2. **Discord Integration**: Webhook execution with thread support
3. **Error Handling**: Retry mechanism with Extended-Discord fallback logging
4. **Memory Management**: Proper cleanup of Webhook and DataPack objects

### Naming Conventions (Project-Specific)
- **Global Variables**: `g_cv` prefix for ConVars, `g_s` for strings, `g_` for booleans
- **Functions**: PascalCase (e.g., `SendWebHook`, `OnWebHookExecuted`)
- **Constants**: ALL_CAPS with descriptive names

## Discord Integration Patterns

### Webhook Configuration
```sourcepawn
// Standard webhook setup pattern
Webhook webhook = new Webhook(sMessage);
webhook.SetUsername(sName);
webhook.SetAvatarURL(sAvatar);

// Thread support (forum channels)
if (IsThread) {
    webhook.SetThreadName(sThreadName); // Creates new thread
    // OR use existing thread ID in Execute()
}
```

### Error Handling Pattern
```sourcepawn
// Retry mechanism with Extended-Discord fallback
if (response.Status != expected_status) {
    if (retries < max_retries) {
        SendWebHook(sMessage, sWebhookURL); // Retry
        retries++;
    } else {
        // Log error with Extended-Discord if available
        #if defined _extendeddiscord_included
            ExtendedDiscord_LogError(...);
        #endif
    }
}
```

## Configuration Management

### ConVar Patterns
- **Protected CVars**: Use `FCVAR_PROTECTED` for sensitive data (webhook URLs)
- **Auto-execution**: `AutoExecConfig(true)` for automatic config file generation
- **Runtime Access**: Cache frequently accessed ConVar values in global variables

### Thread vs Channel Configuration
- `sm_cidr_discord_channel_type`: 0 = Text channel, 1 = Forum thread
- Thread creation: Use `thread_name` for new threads
- Thread targeting: Use `thread_id` for existing threads

## Development Guidelines

### Adding Features
1. **New ConVars**: Follow existing naming pattern `sm_cidr_discord_*`
2. **Discord Features**: Extend `SendWebHook()` function or webhook object
3. **Error Cases**: Always implement retry logic and fallback logging
4. **Memory**: Use `delete` for cleanup, avoid memory leaks

### Code Style (Project-Specific)
- **Indentation**: 4-space tabs (consistent with existing code)
- **Braces**: Opening brace on same line for conditionals
- **Spacing**: Space after keywords (`if (`, `for (`)
- **String Operations**: Use `Format()` for complex string building

### Testing Approach
1. **Build Testing**: Use SourceKnight build system locally
2. **Integration Testing**: Test with actual CIDR plugin on development server
3. **Discord Testing**: Verify webhook delivery with different channel types
4. **Error Testing**: Test retry mechanism and fallback logging

## Common Modification Patterns

### Adding New Discord Fields
```sourcepawn
// In SendWebHook function, before webhook.Execute()
char sNewField[256];
g_cvNewField.GetString(sNewField, sizeof(sNewField));
if (strlen(sNewField) > 0)
    webhook.SetNewProperty(sNewField);
```

### Extending Message Format
```sourcepawn
// In CIDR_OnActionPerformed, modify sMessage formatting
Format(sMessage, sizeof(sMessage), "```Action: %s\nServer: %s\nTime: %s\nDetails: %s```", 
       sAction, g_sServerName, sTime, sAdditionalInfo);
```

### Adding Configuration Options
```sourcepawn
// In OnPluginStart()
g_cvNewOption = CreateConVar("sm_cidr_discord_new_option", "default", "Description", FCVAR_NONE);
```

## Debugging & Troubleshooting

### Common Issues
1. **Webhook Failures**: Check URL validity and channel permissions
2. **Thread Issues**: Verify thread_name/thread_id configuration
3. **Plugin Load Order**: Ensure CIDR plugin loads before this plugin
4. **Dependency Missing**: Check SourceKnight dependency resolution

### Debugging Tools
- **SourceMod Logs**: Check `logs/errors_*.log` for plugin errors
- **Extended-Discord**: Use for enhanced Discord-specific logging
- **ConVar Verification**: Use `sm_cvar find cidr_discord` to check settings

## File Structure & Organization

```
/addons/sourcemod/
├── scripting/
│   └── CIDR_Discord.sp          # Main plugin source
├── plugins/
│   └── CIDR_Discord.smx         # Compiled output (auto-generated)
└── configs/
    └── CIDR_Discord.cfg         # Auto-generated config file
```

## Integration Points

### CIDR Plugin Integration
- **Forward**: `CIDR_OnActionPerformed(int client, int timestamp, char[] sAction)`
- **Library Check**: Plugin registers as "CIDR_Discord" library
- **Dependency**: Requires CIDR plugin to be loaded first

### Optional Extensions
- **Extended-Discord**: Enhanced logging capabilities if available
- **Library Detection**: Uses `LibraryExists()` and library callbacks

## Performance Considerations

### Webhook Efficiency
- **Async Operations**: All Discord API calls are asynchronous
- **Retry Logic**: Bounded retry attempts to prevent infinite loops
- **Memory Cleanup**: Immediate cleanup of webhook objects after execution

### String Operations
- **Buffer Management**: Pre-allocated buffers for message formatting
- **Replace Operations**: Minimal string replacements for newline handling
- **Format Caching**: Cache formatted server name during config execution

## Version Management

- **Plugin Version**: Update in `myinfo` structure
- **Compatibility**: Maintain backward compatibility with SourceMod 1.11+
- **Dependency Versions**: Manage through `sourceknight.yaml`
- **Semantic Versioning**: Follow MAJOR.MINOR.PATCH pattern

## Security Considerations

- **Webhook URLs**: Always use `FCVAR_PROTECTED` for webhook ConVars
- **Input Validation**: Validate Discord message content and thread parameters
- **Error Disclosure**: Avoid logging sensitive information in error messages
- **Rate Limiting**: Respect Discord API rate limits through retry delays