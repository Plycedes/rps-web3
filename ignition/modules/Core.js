const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const { verify } = "../../utils/verify.js";

module.exports = buildModule("CoreModule", (m) => {
    const core = m.contract("Core");

    return { core };
});
