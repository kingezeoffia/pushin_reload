const { Installer } = require('./node_modules/bmad-method/tools/cli/installers/lib/core/installer');

async function installBMAD() {
  const installer = new Installer();

  // Create a configuration object that mimics what the UI would produce
  const config = {
    actionType: 'install', // New installation
    directory: '/Users/kingezeoffia/pushin_reload',
    installCore: true, // Always install core
    modules: ['bmm'], // BMad Method module
    ides: ['cursor'], // Cursor IDE
    skipIde: false,
    coreConfig: { // Provide default core configuration
      user_name: 'Kingezeoffia',
      communication_language: 'English',
      document_output_language: 'English',
      agent_sidecar_folder: '.bmad-user-memory',
      output_folder: 'docs',
      install_user_docs: true
    },
    customContent: { hasCustomContent: false },
    enableAgentVibes: false,
    agentVibesInstalled: false
  };

  try {
    console.log('🚀 Starting BMAD Method installation...');
    const result = await installer.install(config);

    if (result && result.success) {
      console.log('✅ BMAD Method installation completed successfully!');
      console.log(`📁 Installed to: ${result.path}`);
      console.log('\n🎯 Next steps:');
      console.log('1. Load any agent in your IDE (Cursor)');
      console.log('2. Run "*workflow-init" to initialize your project');
      console.log('3. Choose your preferred workflow track');
    } else {
      console.log('❌ Installation failed');
    }
  } catch (error) {
    console.error('💥 Installation error:', error.message);
    console.error(error.stack);
  }
}

installBMAD();
