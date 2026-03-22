#include<iostream>
#include<iomanip>
#include"NTT-RTL-gen/util.hpp"
using namespace std;
signed main(signed argc, char **argv){
    // expected arguments
    // <stage> [inv]
    int stage;
    if(argc<2) return 1;
    try{stage=stoi(argv[1]);}
    catch(const std::exception& e){return 1;}

    bool inv_flag=false;
    if(argc>=3) inv_flag = string("inv")==argv[2];
    
    ctx = new NTTctx(stage);

    vector<vector<int>> buffer1, buffer2;
    // first NTT
    buffer1.resize(ctx->N);
    buffer2.resize(ctx->N);
    for(int i=0; i<ctx->N; ++i){
        buffer1[i].resize(ctx->N);
        buffer2[i].resize(ctx->N);
        for(int j=0; j<ctx->N; ++j){
            cin>>buffer1[i][j];
        }
        if(inv_flag){
            ctx->intt(buffer1[i], buffer2[i]);
            // the rtl code does not mul by N^(-1)
            for(int j=0; j<ctx->N; ++j){
                long long tmp=buffer2[i][j];
                buffer2[i][j]=(tmp*ctx->N)%Q;
            }
        }
        else ctx->ncn(buffer1[i], buffer2[i]);
    }
    // mod mul (skip)
    // output after mod mul
    for(int i=0; i<ctx->N; ++i){
        for(int j=0; j<ctx->N; ++j){
            cout<<setw(10)<<buffer2[i][j]<<' ';
        }
        cout<<'\n';
    }
    // transpose
    for(int i=0; i<ctx->N; ++i){
        for(int j=0; j<ctx->N; ++j){
            buffer1[i][j]=buffer2[j][i];
        }
    }
    // output after transpose
    // for(int i=0; i<ctx->N; ++i){
    //     for(int j=0; j<ctx->N; ++j){
    //         cout<<setw(10)<<buffer1[i][j]<<' ';
    //     }
    //     cout<<'\n';
    // }
    // second NTT
    for(int i=0; i<ctx->N; ++i){
        if(inv_flag){
            ctx->incn(buffer1[i], buffer2[i]);
            // the rtl code does not mul by N^(-1)
            for(int j=0; j<ctx->N; ++j){
                long long tmp=buffer2[i][j];
                buffer2[i][j]=(tmp*ctx->N)%Q;
            }
        }
        else ctx->ntt(buffer1[i], buffer2[i]);
    }
    // output
    // for(int i=0; i<ctx->N; ++i){
    //     for(int j=0; j<ctx->N; ++j){
    //         cout<<setw(10)<<buffer2[i][j]<<' ';
    //     }
    //     cout<<'\n';
    // }

    delete ctx;
    return 0;
}
