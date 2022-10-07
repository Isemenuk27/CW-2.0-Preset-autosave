if !CustomizableWeaponry then return end
if CustomizableWeaponry.preset.enabled then --Edited original code
	if SERVER then
		net.Receive(CustomizableWeaponry.preset.networkString .. ".AUTOSAVEMOD", function(len, ply)
			local name_sv = net.ReadString()
			local data = net.ReadString()
			local wep = net.ReadEntity() --Now we reading it instead of ply:GetActiveWeapon()
			data = util.JSONToTable(data)
			if not IsValid(wep) or not wep.CW20Weapon then return end
			if (wep.ThisClass or wep:GetClass()) ~= data.wepClass then return end
			CustomizableWeaponry.preset.load(wep, data, name_sv)
		end)
		util.AddNetworkString(CustomizableWeaponry.preset.networkString .. ".AUTOSAVEMOD")
	end
end
function CustomizableWeaponry.preset:loadfix(data, name_sv)
	if not CustomizableWeaponry.customizationEnabled then
		return false
	end
	if not CustomizableWeaponry.preset.enabled then return end
	local CT = CurTime()
	if CT < self.PresetLoadDelay then return end
	if !data then return end
	if !self.CW20Weapon then return end
	if CLIENT then
		local preset = file.Read(CustomizableWeaponry.preset.getWeaponFolder(self) .. data .. ".txt", "DATA")
		if not preset or preset == "" then return end
		net.Start(CustomizableWeaponry.preset.networkString .. ".AUTOSAVEMOD")
			net.WriteString(data)
			net.WriteString(preset)
			net.WriteEntity(self)
		net.SendToServer()
	end
	if SERVER then
		if self.LastPreset ~= name_sv then
			local loadOrder = {}
			for k, v in pairs(data) do
				local attCategory = self.Attachments[k]
				if attCategory then
					local att = CustomizableWeaponry.registeredAttachmentsSKey[attCategory.atts[v]]
					if att then
						local pos = 1
						if att.dependencies or attCategory.dependencies or (self.AttachmentDependencies and self.AttachmentDependencies[att.name]) then
							pos = #loadOrder + 1
						end
						table.insert(loadOrder, pos, {category = k, position = v})
					end
				end
			end
			self:detachAll()
			for k, v in pairs(loadOrder) do
				self:attach(v.category, v.position - 1)
			end
			CustomizableWeaponry.grenadeTypes.setTo(self, (data.grenadeType or 0), true)
			self.LastPreset = name_sv
			umsg.Start("CW20_PRESETSUCCESS", self.Owner)
				umsg.String(name_sv)
			umsg.End()
		else
			self:detachAll()
			SendUserMessage("CW20_PRESETDETACH", self.Owner)
			CustomizableWeaponry.grenadeTypes.setTo(self, 0, true)
		end
	end
	self.PresetLoadDelay = CT + CustomizableWeaponry.preset.delay
end

if SERVER then
	local cvar = CreateConVar("cw_preset_autosave_sv", 1, FCVAR_ARCHIVE)
	util.AddNetworkString("CW20.Autoloadattachments")
	local function WeapEquip( weapon, ply )
		if !cvar:GetBool() then return end
		if !weapon.CW20Weapon then return end
		if ply:IsBot() then return end
		timer.Simple(0.5, function()
			if !IsValid(weapon) then return end
			if weapon.disableDropping then return end
			if weapon.DONTAUTOLOADATTS then return end
			weapon.PresetLoadDelay = 0
			weapon.ThisClass = weapon:GetClass()
			net.Start("CW20.Autoloadattachments")
				net.WriteEntity(weapon)
			net.Send(ply)
		end)
	end
	hook.Add( "WeaponEquip", "CW20.WeaponEquip.AutosaveHook", WeapEquip )
	local function fa(ply, ent, wep)
		wep.DONTAUTOLOADATTS = true
	end
	hook.Add("CW20_PickedUpCW20Weapon", "AutosaveHook", fa)
else
	local cvar = CreateConVar("cw_preset_autosave_cl", 1, FCVAR_ARCHIVE)
	net.Receive("CW20.Autoloadattachments", function()
		if !cvar:GetBool() then return end
		local weapon = net.ReadEntity()
		weapon.PresetLoadDelay = 0
		CustomizableWeaponry.preset.loadfix(weapon, "Autosave")
	end)
	local function f(wep)
		local ply = wep:GetOwner()
		if ply != LocalPlayer() then return end
		if !ply then return end
		if ply:IsBot() then return end
		CustomizableWeaponry.preset.save(wep, "Autosave")
	end
	CustomizableWeaponry.callbacks:addNew("postAttachAttachment", "AutosaveCallback1", f)
	CustomizableWeaponry.callbacks:addNew("postDetachAttachment", "AutosaveCallback2", f)
end