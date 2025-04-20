const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("CoreModule", (m) => {
    const core = m.contract("Core");

    return { core };
});
