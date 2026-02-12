function LIBRARY:Initialize(tJSONLib, tChaChaLib, tPolyLib, tLZWLib, tBase64Lib, sKey)
	assert(istable(tJSONLib) and isfunction(tJSONLib.encode) and isfunction(tJSONLib.decode),			"[LIB-CODEC] Invalid JSON library")
	assert(istable(tChaChaLib) and isfunction(tChaChaLib.encrypt) and isfunction(tChaChaLib.decrypt),	"[LIB-CODEC] Invalid ChaCha20 library")
	assert(istable(tPolyLib) and isfunction(tPolyLib.auth),												"[LIB-CODEC] Invalid Poly1305 library")
	assert(istable(tLZWLib) and isfunction(tLZWLib.compress) and isfunction(tLZWLib.decompress),		"[LIB-CODEC] Invalid LZW library")
	assert(isstring(sKey),																				"[LIB-CODEC] Encryption key must be a string")

	return setmetatable(
		{
			JSON		= tJSONLib,
			CHACHA20	= tChaChaLib,
			POLY1305	= tPolyLib,
			LZW			= tLZWLib,
			BASE64		= tBase64Lib,
			KEY			= sKey:gsub("\\x(%x%x)", function(n) return string.char(tonumber(n, 16)) end),
		},
	{ __index	= LIBRARY })
end

function LIBRARY:IsValidData(tData)
	return istable(tData)
	   and isstring(tData.ID)
	   and tData.CONTENT ~= nil
	   and isbool(tData.ENCRYPTED)
	   and isbool(tData.COMPRESSED)
end

function LIBRARY:Compress(sContent)
	assert(istable(self.LZW) and isfunction(self.LZW.compress),	"[LIB-CODEC] LZW.compress missing")
	assert(isstring(sContent),									"[LIB-CODEC] Content must be string")

	local bSuccess;
	bSuccess, sContent	= pcall(self.LZW.compress, sContent)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to compress content, error: " .. tostring(sContent))
	end

	return sContent
end

function LIBRARY:Encrypt(sContent, sKey, sNonce)
	assert(isstring(sContent),												"[LIB-CODEC] Content must be a string")
	assert(isstring(sKey),													"[LIB-CODEC] Key must be a string")
	assert(isstring(sNonce),												"[LIB-CODEC] Nonce must be a string")
	assert(istable(self.CHACHA20) and isfunction(self.CHACHA20.encrypt),	"[LIB-CODEC] CHACHA20.encrypt missing")
	assert(istable(self.POLY1305) and isfunction(self.POLY1305.auth),		"[LIB-CODEC] POLY1305.auth missing")

	local bSuccess, sTag;
	local sPolyKey		= sNonce .. string.rep("\0", 20)

	bSuccess, sContent	= pcall(self.CHACHA20.encrypt, sKey, 1, sNonce, sContent)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to encrypt content, error: " .. tostring(sContent))
	end

	bSuccess, sTag		= pcall(self.POLY1305.auth, sContent, sPolyKey)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to generate Poly1305 tag, error: " .. tostring(sTag))
	end

	return sContent, sTag
end

function LIBRARY:Decrypt(sContent, sKey, sNonce, sTag)
	assert(isstring(sContent),												"[LIB-CODEC] Content must be a string")
	assert(isstring(sKey),													"[LIB-CODEC] Key must be a string")
	assert(isstring(sNonce),												"[LIB-CODEC] Nonce must be a string")
	assert(istable(self.CHACHA20) and isfunction(self.CHACHA20.decrypt),	"[LIB-CODEC] CHACHA20.decrypt missing")
	assert(istable(self.POLY1305) and isfunction(self.POLY1305.auth),		"[LIB-CODEC] POLY1305.auth missing")

	local bSuccess, sDecrypted, bValid;
	local sPolyKey	= sNonce .. string.rep("\0", 20)

	bValid			= (self.POLY1305.auth(sContent, sPolyKey) == sTag)
	if not bValid then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Invalid Poly1305 tag - data tampered")
	end

	bSuccess, sDecrypted = pcall(self.CHACHA20.decrypt, sKey, 1, sNonce, sContent)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to decrypt content, error: " .. tostring(sDecrypted))
	end

	return sDecrypted
end

function LIBRARY:Decompress(sContent)
	assert(istable(self.LZW) and isfunction(self.LZW.decompress),	"[LIB-CODEC] LZW.decompress missing")
	assert(isstring(sContent),										"[LIB-CODEC] Content must be a string")

	local bSuccess;
	bSuccess, sContent	= pcall(self.LZW.decompress, sContent)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to decompress content, error: " .. tostring(sContent))
	end

	return sContent
end

function LIBRARY:Base64Encode(sContent, sTag, sNonce)
	assert(istable(self.BASE64) and isfunction(self.BASE64.encode),	"[LIB-CODEC] BASE64.encode missing")
	assert(isstring(sContent),										"[LIB-CODEC] Content must be a string")

	local bSuccess;
	bSuccess, sContent	= pcall(self.BASE64.encode, sContent)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to encode Base64, error: " .. tostring(sContent))
	end

	bSuccess, sTag		= pcall(self.BASE64.encode, sTag)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to encode Base64 tag, error: " .. tostring(sTag))
	end

	bSuccess, sNonce	= pcall(self.BASE64.encode, sNonce)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to encode Base64 nonce, error: " .. tostring(sNonce))
	end

	return sContent, sTag, sNonce
end

function LIBRARY:Base64Decode(sContent, sTag, sNonce)
	assert(istable(self.BASE64) and isfunction(self.BASE64.decode),	"[LIB-CODEC] BASE64.decode missing")
	assert(isstring(sContent),										"[LIB-CODEC] Content must be a string")

	local bSuccess;
	bSuccess, sContent	= pcall(self.BASE64.decode, sContent)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to decode Base64, error: " .. tostring(sContent))
	end

	bSuccess, sTag		= pcall(self.BASE64.decode, sTag)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to decode Base64 tag, error: " .. tostring(sTag))
	end

	bSuccess, sNonce	= pcall(self.BASE64.decode, sNonce)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to decode Base64 nonce, error: " .. tostring(sNonce))
	end

	return sContent, sTag, sNonce
end

function LIBRARY:Encode(tData)
	assert(istable(self.JSON) and isfunction(self.JSON.encode),	"[LIB-CODEC] JSON.encode missing")
	assert(istable(tData) and self:IsValidData(tData),			"[LIB-CODEC] Invalid data")

	local bSuccess, sJSONContent;

	bSuccess, tData.CONTENT = pcall(self.JSON.encode, tData.CONTENT)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to encode content")
	end

	if tData.COMPRESSED then
		tData.CONTENT = self:Compress(tData.CONTENT)
	end

	if tData.ENCRYPTED then
		tData.NONCE								= "\x00\x00\x00\x00\x00\x00\x00\x4a\x00\x00\x00\x00"
		tData.CONTENT, tData.TAG				= self:Encrypt(tData.CONTENT, self.KEY, tData.NONCE)
		tData.CONTENT, tData.TAG, tData.NONCE	= self:Base64Encode(tData.CONTENT, tData.TAG, tData.NONCE)
	end

	bSuccess, sJSONContent = pcall(self.JSON.encode, tData)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to encode data JSON, error: " .. tostring(sJSONContent))
	end

	return sJSONContent
end

function LIBRARY:Decode(sData)
	assert(istable(self.JSON) and isfunction(self.JSON.decode),	"[LIB-CODEC] JSON.decode missing")
	assert(isstring(sData),										"[LIB-CODEC] Data must be string")

	local bSuccess, tData;

	bSuccess, tData = pcall(self.JSON.decode, sData)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to decode JSON, error: " .. tostring(tData))
	end

	if not self:IsValidData(tData) then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Invalid data format")
	end

	if tData.ENCRYPTED then
		tData.CONTENT, tData.TAG, tData.NONCE	= self:Base64Decode(tData.CONTENT, tData.TAG, tData.NONCE)
		tData.CONTENT							= self:Decrypt(tData.CONTENT, self.KEY, tData.NONCE, tData.TAG)
	end

	if tData.COMPRESSED then
		tData.CONTENT = self:Decompress(tData.CONTENT)
	end

	bSuccess, tData.CONTENT = pcall(self.JSON.decode, tData.CONTENT)
	if not bSuccess then
		return MsgC(Color(231,76,60), "[LIB-CODEC] Failed to decode JSON content")
	end

	return tData.ID, tData.CONTENT
end