let fetch = require('node-fetch');

/**
 * Get specific match detail from https://apifootball.com/
 * @param {{body:{data:{match_id:string}, id:string}}} req
 **/
exports.matchAdapter = async (req) => {
  const footballApiKey = "15fe3e60cc53879ea6ab6a0964838e35ae7565cc2a16e4dbce6289bd4dbd85d9"
  const match_id = req.body.data.match_id || "";
  const url = `https://apiv2.apifootball.com/?action=get_events&match_id=${match_id}&APIkey=${footballApiKey}`;
  let res = await fetch(url)
  let body = await res.json()
  return {
    jobRunID: req.body.id,
    data: body[0],
  };
};