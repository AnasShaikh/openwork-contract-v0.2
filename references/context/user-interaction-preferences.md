# User Interaction Preferences - Context Documentation

**Date Created**: September 23, 2025  
**Purpose**: Document preferred interaction patterns for efficient collaboration

---

## 🎯 **Core Interaction Principles**

### **1. Command Approval Pattern**
- **ALWAYS ASK BEFORE RUNNING COMMANDS**: Never execute bash commands, cast calls, or any operations without explicit user approval
- **Show the exact command**: Display the full command that will be executed
- **Explain what it does**: Brief description of the command's purpose and expected outcome
- **Wait for confirmation**: User will respond with "yes", "y", or similar before proceeding

### **2. Documentation Updates**
- **Update deployment docs immediately**: After each successful deployment, update the relevant documentation in `references/deployments/`
- **Match existing format**: Follow the established format and structure in deployment logs
- **Include all details**: Contract addresses, transaction hashes, deployer addresses, and key changes
- **Real-time updates**: Update docs as deployments happen, not as a batch afterward

### **3. Task Management**
- **Use TodoWrite tool**: Proactively track progress with the TodoWrite tool for multi-step tasks
- **Update status immediately**: Mark tasks as completed right after finishing them
- **Break down complex tasks**: Split large tasks into smaller, trackable steps
- **One task in_progress**: Only one task should be marked as in_progress at a time

---

## 🛠️ **Technical Preferences**

### **4. Error Handling**
- **Don't assume solutions**: When commands fail, investigate the specific error before trying fixes
- **Ask for guidance**: If multiple approaches are possible, ask which direction to take
- **Show error details**: Include relevant error messages and context

### **5. Code Modifications**
- **Show exact changes**: When modifying contracts, show the specific lines being changed
- **Explain why**: Brief explanation of why the modification is needed
- **Update source files**: Make actual changes to source files when needed for deployments

### **6. Cross-Chain Operations**
- **Monitor complete flows**: Track end-to-end processes across multiple chains
- **Check attestations**: Always verify CCTP attestations are ready before completing transfers
- **Log analysis**: Examine transaction logs to confirm successful operations

---

## 📋 **Workflow Patterns**

### **7. Deployment Workflow**
1. **Plan**: Outline what will be deployed and why
2. **Ask**: Get approval for each deployment command
3. **Execute**: Run the approved command
4. **Document**: Update deployment logs immediately
5. **Verify**: Confirm deployment success

### **8. Testing Workflow**
1. **Setup**: Prepare all prerequisites (approvals, configurations)
2. **Step-by-step**: Execute each test step with approval
3. **Monitor**: Watch for expected results and log analysis
4. **Track**: Use TodoWrite to track progress through complex test cycles

### **9. Problem-Solving Approach**
1. **Investigate**: Examine the specific issue or error
2. **Research**: Check existing docs/contracts for context
3. **Propose**: Suggest a solution approach
4. **Confirm**: Get approval before implementing fixes
5. **Document**: Update relevant docs with the solution

---

## 💡 **Communication Style**

### **10. Response Format**
- **Be concise**: Keep explanations focused and relevant
- **Show commands clearly**: Use code blocks for commands
- **Ask specific questions**: Make it easy to give yes/no answers
- **Provide context**: Brief explanation of what the command accomplishes

### **11. When Things Go Wrong**
- **Don't batch failures**: Stop and ask for guidance rather than trying multiple approaches
- **Show the error**: Include the specific error message
- **Suggest next steps**: Propose investigation or alternative approaches

---

## 🎯 **Key Success Patterns**

### **12. What Works Well**
- **Interactive approach**: Step-by-step with approval at each stage
- **Real-time documentation**: Updating docs as we go
- **Thorough testing**: Complete end-to-end test cycles
- **Error investigation**: Taking time to understand failures before retrying

### **13. Avoid These Patterns**
- **Batch operations**: Don't run multiple commands without individual approval
- **Assuming fixes**: Don't try multiple solutions without asking
- **Delayed documentation**: Don't wait until the end to update docs
- **Skipping verification**: Always confirm operations succeeded

---

## 📝 **Documentation Expectations**

### **14. Required Updates**
- **Deployment logs**: Every contract deployment must be documented
- **Architecture changes**: Update system architecture docs when components change
- **Testing results**: Document successful test cycles and any issues discovered
- **Configuration changes**: Record any contract upgrades or parameter updates

### **15. Format Standards**
- **Match existing style**: Follow the established format in existing docs
- **Include timestamps**: Date and time of operations
- **Full details**: Addresses, hashes, gas used, deployer info
- **Status indicators**: Use ✅ for success, ❌ for failures, ⚠️ for warnings

---

**Last Updated**: September 23, 2025  
**Status**: Active interaction guidelines for OpenWork cross-chain development