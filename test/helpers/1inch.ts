import {
    OneInchApiConfig,
    OneInchApiSwapResponse,
    OneInchSwapParams
} from './types'
import axios from 'axios'

export class OneInchApi {
    constructor(private readonly config: OneInchApiConfig) {}

    async requestSwapData(
        swapParams: OneInchSwapParams
    ): Promise<OneInchApiSwapResponse> {
        const url = `${this.config.url}/swap/v5.2/${this.config.network}/swap`;
        // @ts-ignore
        const config = {
            /*headers: {
                "Authorization": `Bearer 0H94bERbr7cACr1BrJ091rpSE8ArV18Y`
            },*/
            params: {
                "src": swapParams.src,
                "dst": swapParams.dst,
                "amount": swapParams.amount,
                "from": swapParams.from,
                "slippage": swapParams.slippage,
                "protocols": (
                    swapParams.protocols
                    ? swapParams.protocols.join(',')
                    : ''
                ),
                "disableEstimate": !!swapParams.disableEstimate
            }
        };

        return axios.get(url, config).then((response) => response.data)
    }
}
